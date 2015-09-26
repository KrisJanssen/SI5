#include <process.h>    /* _beginthread, _endthread */
#include <string>
#include <map>

#include "stdafx.h"
#include "MatlabParams.h"
#include "FrameQueue.h"
#include "FrameCopier.h"
#include "FrameLogger.h"

#define MAX_LSM_COMMAND_LEN 32
#define MAXCALLBACKNAMELENGTH 256


//core objects
// These variables will persist between MEX calls, as they are above the mexFunction declaration.
MatlabParams* fmp;
//FrameQueue* matlabQueue;
FrameCopier* frameCopier;
FrameLogger* frameLogger;
static bool mexInitted = false;

// Called at mex unload/exit
void uninitMEX(void) 
{
  CONSOLETRACE();
  //Gracefully exit
  //Stop Frame Logger.
  if (frameLogger->isLogging())
  {	
    CONSOLEPRINT("STOPPING FRAME LOGGER...\n");
    frameLogger->stopLogging();
  }
  //Stop Frame Copier.
  CONSOLEPRINT("STOPPING FRAME COPIER...\n");
  frameCopier->stopProcessing();
  //************************************************
  mexUnlock();
  mexInitted = false;
  CONSOLEPRINT("VALUE OF mexInitted: %d\n",mexInitted);
}

void initMEX(void) {
#ifdef CONSOLEDEBUG
	NIFPGAMexDebugger::getInstance()->setConsoleAttribsForThread(FOREGROUND_BLUE|FOREGROUND_GREEN|FOREGROUND_INTENSITY);
	CONSOLETRACE();
#endif
	mexLock();
	mexAtExit(uninitMEX);
}

void
asyncMexMATLABCallback(LPARAM lParam, void* fpgaMexParams)
{
	//lParam: Info supplied by postEventMessage
	//void *: Pointer to data/object specified at time of AsyncMex_create()

	mxArray* rhs[3];
	rhs[0] = fmp->callbackFuncHandle;
	rhs[1] = fmp->resonantAcqObject;
	rhs[2] = NULL;
	
	//TODO: Maybe prevent C callback altogether if Matlab callback is empty
	if (mxIsEmpty(rhs[0])) {
		CONSOLEPRINT("In asyncMexMATLABCallback: rhs is empty.\n");
		return;
	}		
	// MATLAB syntax for defining callbackFuncHandle:
	// callbackFuncHandle = @(src,evnt)disp('hello')
	mxArray* mException = mexCallMATLABWithTrap(0,NULL,2,rhs,"feval");

	if (mException!=NULL) {
		char* errorString = (char*)mxCalloc(256,sizeof(char));
		mxArray* tmp = mxGetProperty(mException, 0, "message"); 
		mxGetString(tmp,errorString,MAXCALLBACKNAMELENGTH);
		mxDestroyArray(tmp);
		CONSOLEPRINT("WARNING! asyncMexMATLABCallback: error executing callback: \n\t%s\n", errorString);
		mxFree(errorString);
		mxDestroyArray(mException);
	}
}

enum LSMCommandType { INITIALIZE = 0,
SET_SESSION,
SET_FIFO_NUMBER,
SET_IS_MULTI_CHANNEL,
CREATE_CALLBACK,
RESIZE_ACQUISITION,
REGISTER_FRAMEACQ_CALLBACK,
GET_FRAME,
START_ACQ,
STOP_ACQ,
DELETE_SELF,
UNKNOWN_CMD
};

LSMCommandType getLSMCommand(const char* str) {
	//CONSOLEPRINT("NIFPGAMex: %s\n", str);

	if     (strcmp(str, "init") == 0) { return INITIALIZE; }
	else if(strcmp(str, "setSession") == 0) { return SET_SESSION; } 
	//else if(strcmp(str, "setFifoNumber") == 0) { return SET_FIFO_NUMBER; }
	//else if(strcmp(str, "setIsMultiChannel") == 0) { return SET_IS_MULTI_CHANNEL; }
	//else if(strcmp(str, "createCallback") == 0) { return CREATE_CALLBACK; }
	else if(strcmp(str, "resizeAcquisition") == 0) { return RESIZE_ACQUISITION; } 
	else if(strcmp(str, "registerFrameAcqFcn") == 0) { return REGISTER_FRAMEACQ_CALLBACK; }
	else if(strcmp(str, "getFrame") == 0) { return GET_FRAME; } 
	else if(strcmp(str, "startAcq") == 0) { return START_ACQ; } 
	else if(strcmp(str, "stopAcq") == 0) { return STOP_ACQ; } 
	else if(strcmp(str, "delete") == 0) { return DELETE_SELF; } 

	return UNKNOWN_CMD;
}

void
mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
	if(!mexInitted) {
		initMEX();
		mexInitted = true;

		//create our core objects
		CONSOLETRACE();
		fmp = MatlabParams::getInstance();
		CONSOLETRACE();
		fmp->matlabQueue = new FrameQueue();
		CONSOLETRACE();
		fmp->loggingQueue = new FrameQueue();
		CONSOLETRACE();
		frameCopier = new FrameCopier();
		CONSOLETRACE();
		frameLogger = new FrameLogger();
		CONSOLETRACE();
		//static bool mexInitted = false;
	}

	if(nrhs < 2) {
		mexErrMsgTxt("No command specified.");
	}
	char cmdStr[MAX_LSM_COMMAND_LEN];
	mxGetString(prhs[1],cmdStr,MAX_LSM_COMMAND_LEN);

	LSMCommandType lsmCmd = getLSMCommand(cmdStr);
	if(lsmCmd == UNKNOWN_CMD) {
		char errMsg[256];
		sprintf_s(errMsg,256,"\nconfigureFrameAcquiredEvent: Unrecognized command '%s'.",cmdStr);
		mexErrMsgTxt(errMsg);
	}

	// most commands require that scanner data has been initialized, so perform this check first
	switch(lsmCmd) {

 case INITIALIZE :
	 {
		//Store resonant scanner object
		 const mxArray* objTemp = prhs[0];
		 fmp->resonantAcqObject = mxDuplicateArray(prhs[0]);
		 mexMakeArrayPersistent(fmp->resonantAcqObject);

		 //Store  FPGA object
		 fmp->NIFPGAObject = mxGetProperty(fmp->resonantAcqObject,0,"hFpga");
		 mexMakeArrayPersistent(fmp->NIFPGAObject);

		 //Create AsyncMex 'object'
		 CONSOLEPRINT("Creating callback wrapper: fmp->asyncMex called...\n");
		 fmp->asyncMex = AsyncMex_create((AsyncMex_Callback *) asyncMexMATLABCallback , fmp);
     if (fmp->asyncMex == NULL) {
         CONSOLEPRINT("asyncMex is NULL!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ARGH!\n");
     }

		 //Store session & FIFO handles
		 mxArray* propVal;

		 CONSOLETRACE();
		 propVal = mxGetProperty(fmp->NIFPGAObject,0,"session");
		 fmp->fpgaSession = (NiFpga_Session) mxGetScalar(propVal);
		 //fmp->setSession((NiFpga_Session) mxGetScalar(propVal));
		 //CONSOLEPRINT("SET_SESSION CALLED: fmp->setSession called with value %d\n",(NiFpga_Session) mxGetScalar(propVal));
		 mxDestroyArray(propVal);

		 CONSOLETRACE();
		 propVal = mxGetProperty(fmp->resonantAcqObject, 0, "fpgaFifoNumberSingleChan");
		 fmp->fpgaFifoNumberSingleChan = (uint32_t) mxGetScalar(propVal);
		 CONSOLEPRINT("Got FifoNumberSingleChan: %d\n",fmp->fpgaFifoNumberSingleChan);
		 mxDestroyArray(propVal);

		 CONSOLETRACE();
		 propVal = mxGetProperty(fmp->resonantAcqObject, 0, "fpgaFifoNumberMultiChan");
		 fmp->fpgaFifoNumberMultiChan = (uint32_t) mxGetScalar(propVal);
		 CONSOLEPRINT("Got FifoNumberMultiChan: %d\n",fmp->fpgaFifoNumberMultiChan);
		 mxDestroyArray(propVal);

		 //Create/configure Frame Copier thread/object
		 //do this still
	 }
	 break;

 /*case SET_SESSION :
	 {
		 mxArray* propVal = mxGetProperty(fmp->NIFPGAObject,0,"session");
		 fmp->setSession((NiFpga_Session) mxGetScalar(propVal));
		 CONSOLEPRINT("SET_SESSION CALLED: fmp->setSession called with value %d\n",(NiFpga_Session) mxGetScalar(propVal));
		 mxDestroyArray(propVal);
	 }
	 break;

 case SET_FIFO_NUMBER :
	 {
		 mxArray* propVal = mxGetProperty(fmp->NIFPGAObject,0,"fifoNumber");
		 fmp->setFifoNumber((uint32_t) mxGetScalar(propVal));
		 CONSOLEPRINT("SET_FIFO_ID CALLED: fmp->fpgaFifo called with value %d\n",(uint32_t) mxGetScalar(propVal));
		 mxDestroyArray(propVal);
	 }
	 break;*/

 /*case SET_IS_MULTI_CHANNEL :
	 {
		 mxArray* propVal = mxGetProperty(fmp->resonantAcqObject,0,"multiChannel");
		 fmp->setIsMultiChannel((int) mxGetScalar(propVal));
		 CONSOLEPRINT("SET_IS_MULTI_CHANNEL CALLED: fmp->setIsMultiChannel called with value %d\n",(int) mxGetScalar(propVal));
		 mxDestroyArray(propVal);
	 }
	 break;*/

 //case CREATE_CALLBACK:
	// {
	//	 CONSOLEPRINT("CREATE_CALLBACK CALLED: fmp->asyncMex called...\n");
	//	 fmp->asyncMex = AsyncMex_create((AsyncMex_Callback *) asyncMexMATLABCallback , fmp);
	// }
	// break;

 case RESIZE_ACQUISITION:
	 {
		 //CONSOLETRACE();
		 fmp->readPropsFromMatlab();
         fmp->matlabQueue->init(fmp->frameSizeBytes, fmp->frameQueueCapacity, fmp->frameQueueCapacity);
         fmp->loggingQueue->init(fmp->frameSizeBytes, fmp->frameQueueCapacity, fmp->frameQueueCapacity);
	 }
	 break;

 case REGISTER_FRAMEACQ_CALLBACK: 
	 {
		 mxArray* mxCbk = mxGetProperty(fmp->resonantAcqObject,0,"frameAcquiredFcn");
		 fmp->setCallback(mxCbk);
		 mxDestroyArray(mxCbk);
		 //Duplicate & persistence handled by fmp. Is it actually needed though? If mxGetProperty is a mxCreate equivalent, presumably the fucntion callback mxArray is already duplicated?
	 }
	 break;
	 
 case START_ACQ:
	 {
		 //CONSOLEPRINT("matlabQueue: %d",fmp->matlabQueue);
		 //Start Frame Copier.
		 CONSOLEPRINT("STARTING FRAME COPIER...\n");
		 frameCopier->startProcessing();
     CONSOLETRACE();
         //Start Frame Logger.
		 if (fmp->loggingEnabled)
		 {
			 CONSOLEPRINT("STARTING FRAME LOGGER...\n");
			 frameLogger->configureLogFile();
			 frameLogger->startLogging();
		 }
	 }
	 break;

 case STOP_ACQ:
	 {
         //Stop Frame Logger.
		 if (frameLogger->isLogging())
			 {	
				 CONSOLEPRINT("STOPPING FRAME LOGGER...\n");
				 frameLogger->stopLogging();
			 }
		 //Stop Frame Copier.
		 CONSOLEPRINT("STOPPING FRAME COPIER...\n");
     frameCopier->stopAcquisition();
		 frameCopier->stopProcessing();
	 }
	 break;

 case GET_FRAME: 
	 {
         mwSize frameDims[1];
		 mxArray* data;
         mxArray* dataTransposed;
		 mxArray* dataMatrix;
		 mxArray* tag;
		 mxArray* placeholder;
		 mxArray* dataCellArray;
		 mxArray* elremaining;
		 mxArray* framesremaining;
		 //The following vars are used for de-interlacing multichannel images.
         const int16_t* sourceArray;
         int16_t* destinationArray;
		 int16_t* dataTransposedArray;
		 int16_t* rawData;

		 size_t frameTwoOffset   = fmp->frameSizePixels;
		 size_t frameThreeOffset = fmp->frameSizePixels*2;
		 size_t frameFourOffset  = fmp->frameSizePixels*3;
         unsigned long tagVal = 0;
		 unsigned long placeholderVal = 0;

		 if (!fmp->matlabQueue->isEmpty())
		 {
			 //TODO: Remove any redundant memcpys and extra copies of frame data
			 //TODO: Account for the possibility of frame sizes that do not divide evenly into the FIFO, which requires two reads from the FIFO (first part of data, then second part)
			 frameDims[0] = fmp->frameSizeFifoElements;
			 if (fmp->isMultiChannel){
				 data = mxCreateNumericArray(1,frameDims,mxINT64_CLASS,mxREAL);
				 dataTransposed = mxCreateNumericArray(1,frameDims,mxINT64_CLASS,mxREAL);
			 }
			 else
			 {
				 data = mxCreateNumericArray(1,frameDims,mxINT16_CLASS,mxREAL);
				 dataTransposed = mxCreateNumericArray(1,frameDims,mxINT16_CLASS,mxREAL);
			 }

			 //Start the process by getting the memory location of the front of the frame queue and store in sourceArray.
			 sourceArray = static_cast<const int16_t*>(fmp->matlabQueue->front_unsafe());
			 destinationArray  = static_cast<int16_t*>(mxGetData(data));
			 dataTransposedArray = static_cast<int16_t*>(mxGetData(dataTransposed));

			 // If frameTagging is enabled, then store the frame tag.
			 if (fmp->frameTagging) {
				// ****** BEGIN FRAME TAG PROCESSING LOGIC *******
   	            FrameLogger::frameTag_t tempTag;
				tempTag = *(FrameLogger::frameTag_t*)(sourceArray + (fmp->frameSizeBytes - fmp->tagSizeBytes)/2);
				tagVal = tempTag.fpgaTotalAcquiredRecords;
				placeholderVal = tempTag.fpgaPlaceHolder;
				if (tempTag.fpgaTagIdentifier != -32768){
					CONSOLEPRINT("ERROR: TAG IDENTIFIER IS NOT EXPECTED VALUE - POSSIBLE FRAME DATA CORRUPTION.\n");
				}
			 }

			 memcpy(destinationArray,sourceArray,fmp->frameSizeBytes);

			 //reset pointer to destinationArray so that it points to the beginning of our data.
			 destinationArray  = static_cast<int16_t*>(mxGetData(data));
			 //Once we are done using the sourceArray pointer, we can pop the front off the frame queue.
			 fmp->matlabQueue->pop_front();
			 //Create a 2D cell array of dimension 4x1. Each cell contains a channel frame to send to MATLAB.
			 dataCellArray = mxCreateCellMatrix(4,1);
			 //Create the 2D MATLAB array that will contain the data we just copied into rawData.
			 dataMatrix = mxCreateNumericMatrix(fmp->linesPerFrame,fmp->pixelsPerLine,mxINT16_CLASS,mxREAL);
             //rawData holds pointer to the data stored in dataMatrix.
			 rawData = static_cast<int16_t*>(mxGetData(dataMatrix));

			 if  (fmp->isMultiChannel)
			 {
				 memcpy(rawData,(int16_t *) destinationArray,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,0,mxDuplicateArray(dataMatrix));
				 memcpy(rawData,(int16_t *) destinationArray+frameTwoOffset,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,1,mxDuplicateArray(dataMatrix));
				 memcpy(rawData,(int16_t *) destinationArray+frameThreeOffset,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,2,mxDuplicateArray(dataMatrix));
				 memcpy(rawData,(int16_t *) destinationArray+frameFourOffset,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,3,mxDuplicateArray(dataMatrix));
			 }
			 else
			 {
				 memcpy(rawData,(int16_t *) destinationArray,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,0,mxDuplicateArray(dataMatrix));
			 }
		 }
		 else{
			 mexPrintf("WARNING: Attempted to read frame from empty Frame queue! Frame likely dropped.\n");
			 frameDims[0] = fmp->frameSizeFifoElements;
			 dataCellArray = mxCreateCellMatrix(4,1);
			 data = mxCreateNumericArray(1,frameDims,mxINT16_CLASS,mxREAL);
			 dataTransposed = mxCreateNumericArray(1,frameDims,mxINT16_CLASS,mxREAL);
 			 //Create the 2D MATLAB array that will contain the data we just copied into rawData.
			 dataMatrix = mxCreateNumericMatrix(fmp->linesPerFrame,fmp->pixelsPerLine,mxINT16_CLASS,mxREAL);
			 if  (fmp->isMultiChannel) {
				 //Create a 2D cell array of dimension 4x1. Each cell contains a channel frame to send to MATLAB.
				 mxSetCell(dataCellArray,0,mxDuplicateArray(dataMatrix));
				 mxSetCell(dataCellArray,1,mxDuplicateArray(dataMatrix));
				 mxSetCell(dataCellArray,2,mxDuplicateArray(dataMatrix));
				 mxSetCell(dataCellArray,3,mxDuplicateArray(dataMatrix));
			 } else {
				 mxSetCell(dataCellArray,0,mxDuplicateArray(dataMatrix));
			 }
			 tagVal = 0;
			 placeholderVal = 0; // Allow acquisition to continue. This could be risky in grab/loop mode.
		 }

		 tag = mxCreateDoubleScalar(tagVal);
		 placeholder = mxCreateDoubleScalar(placeholderVal);
		 elremaining = mxCreateDoubleScalar(-32768);
		 framesremaining = mxCreateDoubleScalar(fmp->matlabQueue->size());

		 //Set up left hand side arguments for passing data back to MATLAB.
		 if (nlhs >= 1)
		 {
			 plhs[0] = dataCellArray;
			 plhs[1] = tag;
			 plhs[2] = placeholder;
			 plhs[3] = elremaining;
			 plhs[4] = framesremaining;
		 }
		 //Free memory from heap.
		 mxDestroyArray(dataMatrix);
		 mxDestroyArray(dataTransposed);
		 mxDestroyArray(data);
	 }
	 break;

 case DELETE_SELF:
	 {
		 //frameCopier->stopAcquisition(); //stops thread
		 CONSOLETRACE();

		 if (frameCopier != NULL) {
			 CONSOLEPRINT("DELETING FRAME COPIER...\n");
			 delete frameCopier;
		 }
		 CONSOLETRACE();

		 if (frameLogger != NULL) {
			 CONSOLEPRINT("DELETING FRAME LOGGER...\n");
			 delete frameLogger;
		 }
		 CONSOLETRACE();

		 mexInitted = false;
		 CONSOLETRACE();
		 CONSOLEPRINT("VALUE OF mexInitted: %d\n",mexInitted);
		 CONSOLETRACE();

		 mxDestroyArray(fmp->resonantAcqObject);
		 CONSOLETRACE();
		 mxDestroyArray(fmp->NIFPGAObject);
		 CONSOLETRACE();

		 CONSOLETRACE();
		 if (&fmp->asyncMex != NULL) {
			 AsyncMex_destroy(&fmp->asyncMex);
			 CONSOLETRACE();
		 }

		 CONSOLETRACE();
		 if (fmp != NULL) {
			 CONSOLETRACE();
			 delete fmp;
			 CONSOLETRACE();
		 }
	 }
	 break;

	}
}

//--------------------------------------------------------------------------//
// NIFPGAMex.cpp                                                            //
// Copyright © 2015 Vidrio Technologies, LLC                                //
//                                                                          //
// ScanImage 5 is licensed under the Apache License, Version 2.0            //
// (the "License"); you may not use any files contained within the          //
// ScanImage 5 release  except in compliance with the License.              //
// You may obtain a copy of the License at                                  //
// http://www.apache.org/licenses/LICENSE-2.0                               //
//                                                                          //
// Unless required by applicable law or agreed to in writing, software      //
// distributed under the License is distributed on an "AS IS" BASIS,        //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. //
// See the License for the specific language governing permissions and      //
// limitations under the License.                                           //
//--------------------------------------------------------------------------//
