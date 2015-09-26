#pragma once

#include "stdafx.h"
#include "FrameCopier.h"
#include <sstream>
#include <process.h>
#include "StateModelObject.h"
#include "FrameQueue.h"

FrameCopier::FrameCopier(void) : 
fProcessing(0),
fFramesSeen(0),
fFramesMissed(0),
fLastFrameTagCopied(0),
fInputBuffer(NULL),
fOutputBuffer(NULL),
fLoggingBuffer(NULL),
fDeinterlaceBuffer(NULL),
fMatlabFilteredInputBuf(NULL),
fOutputDataFilteredInputBuf(NULL),
fFrameTagEnable(true),
fMatlabDecimationFactor(1),
fmp(MatlabParams::getInstance()),
fStopAcquisition(false)

#define threadSafePrint(...) EnterCriticalSection(&fProcessFrameCS); _cprintf(__VA_ARGS__); LeaveCriticalSection(&fProcessFrameCS)
{
	fNewFrameEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fNewFrameEvent!=NULL);
	fStartAcqEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fStartAcqEvent!=NULL);
	fKillEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fKillEvent!=NULL);

	InitializeCriticalSection(&fProcessFrameCS);

	fmp->asyncMex = NULL;
	fmp->callbackEnabled = false;
}

FrameCopier::~FrameCopier(void)
{
	if (fThread!=0) {
		kill();
	}

	CFAEMisc::closeHandleAndSetToNULL(fNewFrameEvent);
	CFAEMisc::closeHandleAndSetToNULL(fStartAcqEvent);
	CFAEMisc::closeHandleAndSetToNULL(fKillEvent);
	DeleteCriticalSection(&fProcessFrameCS);

	// fInputBuffer, fOutputQs, fmp->asyncMex not owned
	// by TFC.
}

HANDLE
FrameCopier::getNewFrameEvent(void) const
{
	return fNewFrameEvent;
}



void
FrameCopier::configureMatlabCallback(AsyncMex *asyncMex)
{
	assert(fState==CONSTRUCTED);

	assert(asyncMex!=NULL);
	fmp->asyncMex = asyncMex;
}

void
FrameCopier::setMatlabCallbackEnable(bool enable)
{
	assert(fState==CONSTRUCTED);

	fmp->callbackEnabled = enable;
}

void
FrameCopier::setMatlabDecimationFactor(unsigned int fac)
{
	assert(fState==CONSTRUCTED);

	if (fac==0) {
		fac = 1;
	}
	fMatlabDecimationFactor = fac;
}

void
FrameCopier::setOutputQueues(const std::vector<FrameQueue*> &outputQs)
{
	assert(fState==CONSTRUCTED);

	fOutputQs = outputQs;
}

void
FrameCopier::setMatlabQueue(FrameQueue *q)
{
	assert(fState==CONSTRUCTED);

	fMatlabQ = q;
}


bool
FrameCopier::arm(void)
{
	assert(fState<=ARMED);

	bool tfSuccess = true;

	/// perform verifications, but don't change any state (clear
	/// queues), etc.

	//TODO - put in more array size verifications, taking frameTag into account
	if (fLoggingBuffer==NULL) {
		CONSOLETRACE();
		tfSuccess = false;
	}
	if (fDeinterlaceBuffer==NULL) {
		CONSOLETRACE();
		tfSuccess = false;
	}
	if (fInputBuffer==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	if (fOutputBuffer==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	if (fMatlabQ==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	//if (fInputImageSize!=fMatlabQ->recordSize()) { 
	//  CONSOLETRACE();
	//  tfSuccess = false; 
	//}
	if (fOutputQs.empty()) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	//std::size_t numQs = fOutputQs.size();
	//for (std::size_t i=0;i<numQs;i++) {
	//  if (fInputImageSize!=fOutputQs[i]->recordSize()) { 
	//    CONSOLETRACE();
	//    tfSuccess = false; 
	//  }
	//}

	if (fmp->asyncMex==NULL) {
		CONSOLETRACE();
		tfSuccess = false; 
	}
	assert(fThread!=0);
	assert(fProcessing==0);

	if (tfSuccess) {
		fState = ARMED;
	}

	return tfSuccess;
}

void 
FrameCopier::disarm(void)
{
	assert(fState==ARMED || fState==STOPPED);
	assert(fThread!=0);
	assert(fProcessing==0);

	fState = CONSTRUCTED;
}

void
FrameCopier::startAcq(void)
{
	SetEvent(fStartAcqEvent);
}

void
FrameCopier::startProcessing(void) //const std::vector<int> &outputQsEnabled)
{
	MatlabParams* fmp = MatlabParams::getInstance();

	assert(fState==ARMED || fState==STOPPED);
	CONSOLETRACE();
	CONSOLEPRINT("matlabQueue: %d",fmp->matlabQueue);

	//fOutputQsEnabled = outputQsEnabled; 

	// If processed data or output Q is not empty, that is unexpected. Throw up a MsgBox.
	if (!fmp->matlabQueue->isEmpty())
	{
		CONSOLETRACE();
		CONSOLEPRINT("FrameCopier: Processed data queue has size %d!\n",fmp->matlabQueue->size());
		//Clear the frame queue if there is any residual data from a previous run.
		fmp->matlabQueue->reinit();
	}

	//ResetEvent(fStartAcqEvent);
	//ResetEvent(fNewFrameEvent);
	//ResetEvent(fKillEvent);
	CONSOLETRACE();

	safeStartProcessing();

	CONSOLETRACE();
	fThread = (HANDLE) _beginthreadex(NULL, 0, FrameCopier::threadFcn, (LPVOID)this, 0, NULL);
	CONSOLETRACE();

	//Set thread state to RUNNING if fThread is not 0.
	assert(fThread!=0);
	fState = RUNNING;
}

void
FrameCopier::stopProcessing(void)
{
	assert(fState==RUNNING || fState==STOPPED || fState==PAUSED);
	assert(fThread!=0);

	// Send stop signal.
	safeStopProcessing();
	// Stop signal sent. Now wait for logging thread to terminate.

	DWORD retval = WaitForSingleObject(fThread,STOP_TIMEOUT_MILLISECONDS);
	switch (retval) {
	  case WAIT_OBJECT_0:
		  // logging thread completed.
		  {
			  BOOL b = CloseHandle(fThread);
			  assert(b!=0);
			  fThread = 0;
		  }
		  fState = STOPPED;
		  break;

	  case WAIT_TIMEOUT:
	  case WAIT_ABANDONED:
	  case WAIT_FAILED:
	  default:
		  CONSOLEPRINT("FrameCopier::HARD STOP!!\n");
		  assert(fState==STOPPED || fState==KILLED);

		  if (fState==STOPPED) {
			  CONSOLEPRINT("FrameCopier: Copier could not finish processing. %d frames were unlogged.\n", fmp->matlabQueue->size());
		  }

		  break;
	}
}

bool
FrameCopier::isProcessing(void) const
{
	return fProcessing!=0;
}

void
FrameCopier::pauseProcessing(void)
{
	assert(fState==RUNNING || fState==PAUSED);

	safeStopProcessing();

	fState = PAUSED;
}

void
FrameCopier::resumeProcessing(void)
{
	assert(fState==PAUSED);

	safeStartProcessing();

	fState = RUNNING;
}

unsigned int
FrameCopier::getFramesSeen(void) const
{
	return fFramesSeen;  
}

unsigned int
FrameCopier::getFramesMissed(void) const
{
	return fFramesMissed;  
}


void
FrameCopier::kill(void)
{  
	DWORD threadExitCode = 0; // Used to store exit code for proper call of Terminate Thread.
	//	BOOL returnValue;

	SetEvent(fKillEvent); // nonblocking termination of processing thread
	//	returnValue = GetExitCodeThread(fThread, (LPDWORD) threadExitCode); // get Exit code for fThread from Windows.
	//	CONSOLEPRINT("GetExitCodeThread status: %d, error code: %d\n",returnValue, GetLastError());
	//	returnValue = TerminateThread(fThread,threadExitCode); // Forcibly terminate thread using threadExitCode.
	//	CONSOLEPRINT("TerminateThread status: %d, error code: %d\n",returnValue, GetLastError());
	CloseHandle(fThread); // Does not forcibly terminate thread, only releases handle. Close handle for cleanup.
	fThread = 0;
	fState = KILLED;
}

void
FrameCopier::debugString(std::string &s) const
{
	std::ostringstream oss;
	oss << "--FrameCopier--" << std::endl;
	oss << "State Processing FramesSeen FramesMissed: " 
		<< fState << " " << fProcessing << " " << fFramesSeen << " " 
		<< fFramesMissed << std::endl;
	oss << "MLCBI.enable MatlabDecimationFactor: "
		<< fmp->callbackEnabled << " " 
		<< fMatlabDecimationFactor << std::endl;
	s.append(oss.str());
}

void
FrameCopier::safeStartProcessing(void)
{
	CONSOLETRACE();
	CONSOLEPRINT("Safe start processing\n");

	EnterCriticalSection(&fProcessFrameCS); 
	CONSOLETRACE();
	fFramesSeen = 0;
	fFramesMissed = 0;
	fLastFrameTagCopied = -1;
	fProcessing = 1;
	fStopAcquisition = false;
	LeaveCriticalSection(&fProcessFrameCS);
	CONSOLETRACE();
}

void
FrameCopier::safeStopProcessing(void)
{
	EnterCriticalSection(&fProcessFrameCS); 
	fProcessing = 0;
	LeaveCriticalSection(&fProcessFrameCS);
}

void FrameCopier::stopAcquisition(){
	fStopAcquisition = true;
}

void*
FrameCopier::trueFree(void * fMem)
{
	if (fMem != NULL)
		free(fMem);
	return NULL;
}

// Threading impl notes.  
//
// Some TFC state accessed by the processing thread cannot change
// while threadFcn (or downstream calls) accesses it, due to
// constraints provided by the state model. Examples are fInputBuffer, fOutputQs.
// 
// The only TFC state that is truly shared by the processing thread
// and controller thread are the Events, fProcessing, fFramesSeen,
// fFramesMissed. These are protected with fProcessFrameCS.
//
// At the moment, no state changes (changes to fState) can originate
// in the processing thread (within threadFnc). For example, if
// something bad happens, the processing thread cannot call
// obj->stopProcessing() to put obj's state into STOPPED. The reason
// is that stopProcessing() and other state-change methods are not
// thread-safe with respect to each other, as explained in header.
//
// If in the future there is the need to enable this sort of state
// change, all state-change methods (ALL interactions involving
// potential modification to fState) will need to be protected with
// critical_sections or the like.

unsigned int 
WINAPI FrameCopier::threadFcn(LPVOID userData)
{
#ifdef CONSOLEDEBUG
	NIFPGAMexDebugger::getInstance()->setConsoleAttribsForThread(FOREGROUND_GREEN|FOREGROUND_INTENSITY);
#endif
	FrameCopier *obj = static_cast<FrameCopier*>(userData);

	HANDLE evtArray[3];
	evtArray[0] = obj->fKillEvent;
	evtArray[1] = obj->fStartAcqEvent;
	evtArray[2] = obj->fNewFrameEvent;

	//Instantiate the MatlabParams singleton.	
	MatlabParams* fmpThread = MatlabParams::getInstance();

	//Instantiate and initialize local copy of frameSizeBytes & frameQueueCapacity
	size_t localframeSizeBytes = -1;
	//unsigned long localFrameQueueCapacity = fmpThread->frameQueueCapcity;
	//mem allocation
	size_t* elementsRemaining = (size_t*) calloc(1,sizeof(size_t));

	int acqModeCount = 0;
	int acqCount = 0;
	int deinterlaceCount = 0;
	size_t sourceOffset = 0;
	size_t destinationOffset = 0;
	bool forceEvent = false;
	bool isInitialized = false;
	bool pushbackOK = false;
	int16_t* sourceArray;
	int16_t* destinationArray;
	size_t smallOffset      = 4;
	size_t frameTwoOffset   = fmpThread->frameSizePixels;
	size_t frameThreeOffset = fmpThread->frameSizePixels*2;
	size_t frameFourOffset  = fmpThread->frameSizePixels*3;
	uint64_t simulatedFrameCount = 1;
	uint64_t simulatedAcquisitionCount = 0;
	int xiter, yiter;
	frameTag_t tempTag;

	while(true){
		//reset force to MATLAB event signal to false.
		forceEvent = false;
		//reset fmpThread->fpgaStatus to default timeout status.
		fmpThread->fpgaStatus = NiFpga_Status_FifoTimeout;

		//check for stop signal
		if(obj->fStopAcquisition){
			CONSOLETRACE();
			break;
		}

		if(!obj->isProcessing()){
			CONSOLETRACE();
			break;
		}

		//Initialize FPGA context in this thread - does this /need/ to be in the while loop??
		if (!isInitialized) {
			CONSOLETRACE();
			assert(obj->fProcessing == 0);
			fmpThread->fpgaStatus = NiFpga_Initialize();
			if (!fmpThread->simulated)
				fmpThread->fpgaStatus = NiFpga_Initialize();
			else
				fmpThread->fpgaStatus = NiFpga_Status_Success;

			if(fmpThread->fpgaStatus != NiFpga_Status_Success){
				CONSOLEPRINT("Error initializing FPGA interface context. Got Status: %d\n",fmpThread->fpgaStatus);
			}else
				isInitialized = true;
		}

		// Check to see if the user has changed either linesPerFrame or pixelsPerLine. If so, then recompute framesize,
		// free the old fInputBuffer, and re-calloc the fInputBuffer to the correct size.
		if ((fmpThread->frameSizeBytes != localframeSizeBytes)) {
			assert(obj->fProcessing == 0);
			CONSOLEPRINT("Resizing fInputBuffer to %d bytes\n", fmpThread->frameSizeBytes);

			// Recompute offsets for de-interlacing
			frameTwoOffset   = fmpThread->frameSizePixels;
			frameThreeOffset = fmpThread->frameSizePixels*2;
			frameFourOffset  = fmpThread->frameSizePixels*3;

			// Set local copies of lpp and ppl to the new values.
			localframeSizeBytes = fmpThread->frameSizeBytes;

			// Free the old memory associated with the fInputBuffer.
			obj->fInputBuffer = (char*) obj->trueFree(obj->fInputBuffer);
			obj->fDeinterlaceBuffer = (char*) obj->trueFree(obj->fDeinterlaceBuffer);
			obj->fLoggingBuffer = (char*) obj->trueFree(obj->fLoggingBuffer);
			obj->fOutputBuffer = (char*) obj->trueFree(obj->fOutputBuffer);

			// Resize input buffer
			obj->fInputBuffer = (char*) calloc(localframeSizeBytes, sizeof(char));
			obj->fDeinterlaceBuffer = (char*) calloc(localframeSizeBytes, sizeof(char));
			obj->fLoggingBuffer = (char*) calloc(localframeSizeBytes, sizeof(char));
			obj->fOutputBuffer = (char*) calloc(localframeSizeBytes, sizeof(char));

			CONSOLEPRINT("Resized fmpThread->frameSize: %d\n",(int) fmpThread->frameSizeBytes);
		}

		if (obj->isProcessing()) {
			//Polling for frames via NiFpga_ReadFIFO. This blocks automatically when there are no frames.
			if(!fmpThread->simulated)
			{
				if(fmpThread->isMultiChannel) {
					fmpThread->fpgaStatus = NiFpga_ReadFifoI64(fmpThread->fpgaSession, fmpThread->fpgaFifoNumberMultiChan, (int64_t*)obj->fInputBuffer, fmpThread->frameSizeFifoElements, FRAME_WAIT_TIMEOUT,  elementsRemaining);
					//CONSOLEPRINT("NiFpga_ReadFifoI64. Session: %d,  Frame Size: %d, Elements Remaining: %d\n", (NiFpga_Session)fmpThread->fpgaSession,  (int) fmpThread->frameSizeFifoElements, (int) *elementsRemaining);            
				}
				else {
					fmpThread->fpgaStatus = NiFpga_ReadFifoI16(fmpThread->fpgaSession, fmpThread->fpgaFifoNumberSingleChan, (int16_t*)obj->fInputBuffer, fmpThread->frameSizeFifoElements, FRAME_WAIT_TIMEOUT, elementsRemaining);
					//CONSOLEPRINT("NiFpga_ReadFifoI16. Session: %d, FIFO number: %d, Frame Size: %d, Elements Remaining: %d\n", (NiFpga_Session)fmpThread->fpgaSession, fmpThread->fpgaFifoNumberSingleChan, (int) fmpThread->frameSizeFifoElements, (int) *elementsRemaining);            
				}
			}
			else {
				//***********************************************************************************
				//BEGIN SIMULATED INPUT CODE
				//***********************************************************************************
				fmpThread->fpgaStatus = NiFpga_Status_Success; // always simulate NiFpga Success to 0.
				*elementsRemaining = 0; // always elementsRemaining is zero.

				//Create gradient on all channels.
				int tCount = 0;
				int channelCount = 0;
				int xiter,yiter = 0;
				int16_t* myArray;
				int16_t pixelValMultiplier = 0;

				if(fmpThread->isMultiChannel){
					tCount = 4 * fmpThread->pixelsPerLine * (acqCount % (fmpThread->linesPerFrame - 64));
					myArray = reinterpret_cast<int16_t*> (obj->fInputBuffer);
					for (yiter=0; yiter < 64; yiter++) {
						pixelValMultiplier = (int16_t) (yiter > 1);
						for (xiter=0; xiter < fmpThread->pixelsPerLine; xiter++)
							for (channelCount=0;channelCount<4;channelCount++)
								myArray[tCount++] = (int16_t) xiter * pixelValMultiplier;
					}
				}
				else
				{
					tCount = fmpThread->pixelsPerLine * (acqCount % (fmpThread->linesPerFrame - 64));
					myArray = reinterpret_cast<int16_t*> (obj->fInputBuffer);
					for (yiter=0; yiter < 64; yiter++) {
						pixelValMultiplier = (int16_t) (yiter > 1);
						for (xiter=0; xiter < fmpThread->pixelsPerLine; xiter++)
							myArray[tCount++] = (int16_t) xiter * pixelValMultiplier;
					}
				}
				//Add Simulated Frame Tag (if tagging enabled.)
				if (fmpThread->frameTagging) {
					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2] = -32768;
					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+1] = 0;
					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+2]  = (uint16_t) simulatedFrameCount & 0xFFFF;
					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+3]  = (uint16_t) (simulatedFrameCount >> 16);

					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+4]  = (uint16_t) ((simulatedFrameCount - 1) >> 32);
					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+5]  = (uint16_t) ((simulatedFrameCount - 1) >> 48);
					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+6]  = (uint16_t)  (simulatedFrameCount - 1) & 0xFFFF;
					myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+7]  = (uint16_t) ((simulatedFrameCount - 1) >> 16);

					if (simulatedFrameCount >= fmpThread->framesPerAcquisition) {
						myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2 + 1]  = 0x2; // Signal end of Acquisition.
						simulatedFrameCount = 0;
						simulatedAcquisitionCount = simulatedAcquisitionCount + 1;
						if (simulatedAcquisitionCount >= fmpThread->acquisitionsPerAcquisitionMode) {
							myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2 + 1]  = 0x3; // Signal end of Acquisition Mode.
						}
					}
					else
						myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2 + 1]  = 0;

					simulatedFrameCount++;
				}
				Sleep(fmpThread->simulatedFramePeriod);
				//***********************************************************************************
				//END SIMULATED INPUT CODE
				//***********************************************************************************
			}

			// Increment Frame Counters
			acqModeCount++;     // Frame count for Acq Mode.
			acqCount++;         // Frame count for Acq.

			if (acqModeCount % 100 == 0) {
				CONSOLEPRINT("FrameCopier count %d -- Session: %d,  Frame Size in Elements: %d, Elements Remaining: %d\n", acqModeCount, (NiFpga_Session)fmpThread->fpgaSession,  fmpThread->frameSizeFifoElements, (int) *elementsRemaining);			
			}

			if(fmpThread->fpgaStatus == NiFpga_Status_FifoTimeout) {
				//threadSafePrint("FIFO timeout. Retrying.");
				CONSOLEPRINT("Read FIFO timeout. Retrying...\n");
				continue;
			} else if(fmpThread->fpgaStatus != NiFpga_Status_Success) {
				CONSOLEPRINT("Error reading from FIFO. Got Status: %d\n", fmpThread->fpgaStatus);		
			} else if(fmpThread->fpgaStatus == NiFpga_Status_Success) {
				//********************************************************************************
				//BEGIN TAG PROCESSING CODE
				//********************************************************************************
				//NOTE: Only process tag if we are batching or decimating frames.
				tempTag = *(frameTag_t*)(reinterpret_cast<int16_t*>(obj->fInputBuffer) + (fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2);

				//acquisitionFlags format (uint16)
                //                           +------- DC overvoltage
                //                           | +----- end of acquisition
                //                           | | +--- end of acquisition mode
                //                           | | |
                // 0 0 0 0 0 0 0 0 0 0 0 0 0 x x x
                // |                             |
                // 16                            1
				// Conditions for forcing frame to MATLAB - end of Acq or first frame of Acq.
				if (((tempTag.fpgaPlaceHolder & 2) > 0) || (acqCount == 1)) {
					forceEvent = true;
				}
				// Reset the acqCount if end of Acq.
				if ((tempTag.fpgaPlaceHolder & 2) > 0) {
					acqCount = 0;
				}
				//********************************************************************************
				//END TAG PROCESSING CODE
				//********************************************************************************
				//*************** BEGIN FRAME DEINTERLACING *******************
				if (fmpThread->isMultiChannel) {
					deinterlaceCount = 0;
					sourceArray = reinterpret_cast<int16_t*>(obj->fInputBuffer);
					destinationArray  = reinterpret_cast<int16_t*>(obj->fDeinterlaceBuffer);
					while (deinterlaceCount < fmpThread->frameSizePixels) {
						*destinationArray                      = *(sourceArray++);
						*(destinationArray + frameTwoOffset)   = *(sourceArray++);
						*(destinationArray + frameThreeOffset) = *(sourceArray++);
						*(destinationArray + frameFourOffset)  = *(sourceArray++);
						destinationArray++;
						deinterlaceCount++;
					}
				}
				//*************** STEP 2:BEGIN IMAGE TRANSPOSE *******************
				int transposeCount = 0;
				if (fmpThread->isMultiChannel) {
					sourceArray = reinterpret_cast<int16_t*>(obj->fDeinterlaceBuffer);
					destinationArray  = reinterpret_cast<int16_t*>(obj->fOutputBuffer);
					for (yiter=0;yiter < fmpThread->pixelsPerLine;yiter++)
						for (xiter=0;xiter < fmpThread->linesPerFrame;xiter++) {
							destinationArray[transposeCount]                  = sourceArray[yiter + (xiter * fmpThread->pixelsPerLine)];
							destinationArray[transposeCount+frameTwoOffset]   = sourceArray[frameTwoOffset + yiter + (xiter * fmpThread->pixelsPerLine)];
							destinationArray[transposeCount+frameThreeOffset] = sourceArray[frameThreeOffset + yiter + (xiter * fmpThread->pixelsPerLine)];
							destinationArray[transposeCount+frameFourOffset]  = sourceArray[frameFourOffset + yiter + (xiter * fmpThread->pixelsPerLine)];
							transposeCount++;
						}
				}
				else
				{
					sourceArray = reinterpret_cast<int16_t*>(obj->fInputBuffer);
					destinationArray  = reinterpret_cast<int16_t*>(obj->fOutputBuffer);
					for (yiter=0;yiter < fmpThread->pixelsPerLine;yiter++)
						for (xiter=0;xiter < fmpThread->linesPerFrame;xiter++)
							destinationArray[transposeCount++] = sourceArray[yiter + (xiter * fmpThread->pixelsPerLine)];
				}

				//*************** STEP 3: BEGIN FRAME TAG COPY *******************
				//TODO: Clean this up.
				if (fmpThread->frameTagging) {
					//Display Frame Case
					sourceArray = reinterpret_cast<int16_t*>(obj->fInputBuffer);
					destinationArray  = reinterpret_cast<int16_t*>(obj->fOutputBuffer);

					for (xiter = 0; xiter < (fmpThread->tagSizeBytes/2); xiter++)
						destinationArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+xiter] = sourceArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+xiter];

					//Extra Logging Frame Case for Multichannel.
					if (fmpThread->isMultiChannel) {
						destinationArray  = reinterpret_cast<int16_t*>(obj->fDeinterlaceBuffer);

						for (xiter = 0; xiter < (fmpThread->tagSizeBytes/2); xiter++)
							destinationArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+xiter] = sourceArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+xiter];
					}
				}

				//push it to Matlab queue and logging queue
				//push back fInputBuffer (or fLoggingBuffer) into matlab queue for processing.
				//Now that we have the frame, signal event to matlab to read queue and display image.
				if(forceEvent) {
					// If we have some kind of a bit from the FPGA, then force a MATLAB event to process the frame.
					if(fmpThread->matlabQueue->push_back(obj->fOutputBuffer,forceEvent)) // Put the frame in the frame queue.
					{
						AsyncMex_postEventMessage(fmpThread->asyncMex,0);
					}
				} else if(acqModeCount % fmpThread->displayDecimationFactor == 0) // Decimate frames by factor of displayDecimationFactor (1 = no decimation.)
					if(fmpThread->matlabQueue->push_back(obj->fOutputBuffer,forceEvent)) // Put the frame in the frame queue.
						if (acqModeCount % fmpThread->displayBatchingFactor == 0) // Only send an event to MATLAB by the specified batching factor (1 = batches of size 1 frame.)
							AsyncMex_postEventMessage(fmpThread->asyncMex,0);

				// Insert call to logger here...
				if (fmpThread->loggingEnabled)
					if (fmpThread->isMultiChannel) {
						//If multichannel logging, then only send the channels of interest to
						//the logging thread.
						sourceArray = reinterpret_cast<int16_t*>(obj->fDeinterlaceBuffer);
						destinationArray  = reinterpret_cast<int16_t*>(obj->fLoggingBuffer);
						//TODO: Unify all this copying so that we don't have to do it so many times.
						//This is expensive because of the edge case where the logging channels differ
						//from the display channels. This code would be significantly faster if we were
						//to force the mode that the user must display and log the same channels.
						for (xiter = 0; xiter < (fmpThread->numLoggingChannels); xiter++){
							//Logging channels array contains some, none, or all of the values between 1,2,3, and 4.
							sourceOffset = fmpThread->frameSizePixels * ((size_t)fmpThread->loggingChannelsArray[xiter] - 1);
							destinationOffset = fmpThread->frameSizePixels * xiter;
							memcpy(destinationArray + destinationOffset,sourceArray + sourceOffset,fmpThread->frameSizePixels*sizeof(int16_t));
						}
						//Copy the tag
						memcpy(destinationArray + (fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2, sourceArray + (fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2, fmpThread->tagSizeBytes);
						if (!fmpThread->loggingQueue->push_back(obj->fLoggingBuffer,false)) {
							CONSOLEPRINT("Problem pushing frame back into logging queue...\n");
						}
					}
					else {
						if (!fmpThread->loggingQueue->push_back(obj->fInputBuffer,false)) {
							CONSOLEPRINT("Problem pushing frame back into logging queue...\n"); 
						}
					}
			}
		}
		// Relinquish Control of Thread
		Sleep(0); 
	}
	CONSOLETRACE();
	//mem deallocation
	obj->fInputBuffer = (char*) obj->trueFree(obj->fInputBuffer);
	obj->fDeinterlaceBuffer = (char*) obj->trueFree(obj->fDeinterlaceBuffer);
	obj->fLoggingBuffer = (char*) obj->trueFree(obj->fLoggingBuffer);
	obj->fOutputBuffer = (char*) obj->trueFree(obj->fOutputBuffer);
	elementsRemaining = (size_t*) obj->trueFree(elementsRemaining);

	//normal exit
	return 0;
}

//--------------------------------------------------------------------------//
// FrameCopier.cpp                                                          //
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
