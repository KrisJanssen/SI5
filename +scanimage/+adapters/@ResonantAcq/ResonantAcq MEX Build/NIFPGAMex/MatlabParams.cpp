#include "MatlabParams.h"

const char *MatlabParams::DEFAULT_LOG_FILENAME = "default_file";

MatlabParams* MatlabParams::instance = NULL;
MatlabParams* MatlabParams::getInstance(){
  if(!instance){
    instance = new MatlabParams;
  }
  return instance;
}

MatlabParams::MatlabParams(){
  //simulated operation.
  simulated = false;

  //most values are set in readPropsFromMatlab
  callbackFuncHandle = NULL;
  pixelsPerLine = 0;
  linesPerFrame = 0;

  //TODO: Figure out what to do with these...do we need them in MATLAB?
  pixelSizeBytes = 2;
  numLoggingChannels = 1;
  signedData = true;
  frameDelay = 0;
  frameTagOneBased = true;
  loggingAverageFactor = 1;
  sampleRate = 0;
  loggingSlowStack = false;
  loggingNumSlowStackSlices = 0;
  simulatedFramePeriod = 30;
  framesPerAcquisition = 0;
  framesPerStack = 0;
  acquisitionsPerAcquisitionMode = 0;
  loggingFramesPerFile = 0;
  loggingFramesPerFileLock = false;
  displayDecimationFactor = 1;
  displayBatchingFactor = 1;
  inf = mxGetInf(); // Call mxGetInf() to get double value of Inf on this system.

  //Instrumentation vars
  numDroppedFramesCopier = 0;
  lastCopierTag = 0;
  frameTimestampOffset = 0;
  loggingFileCounter = 0;
  loggingFileSubCounter = 1;
  lastNextFileMarkerTimestamp = 0;
  lastAcqTriggerTimestamp = 0;
}

MatlabParams::~MatlabParams(){
  //clear instance for successive creations.
  instance = NULL;
}

void MatlabParams::readPropsFromMatlab(){
  //Reads the value of each property from the Matlab ResonantAcq class.
  //Note that Matlab's ResonantAcq class is dynamic; many properties don't
  //exist until they are created by reading them from the bitfile.

  mxArray* propVal;

  //samplerate of FPGA
  propVal = mxGetProperty(resonantAcqObject,0,"sampleRate");
  sampleRate = (double) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("sampleRate: %d\n",simulated);

  //simulation mode
  propVal = mxGetProperty(resonantAcqObject,0,"simulated");
  simulated = (bool) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("simulated mode: %d\n",simulated);

  //acquisition-specific parameters
  propVal = mxGetProperty(resonantAcqObject,0,"pixelsPerLine");
  pixelsPerLine = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("pixelsPerLine: %d\n",pixelsPerLine);

  propVal = mxGetProperty(resonantAcqObject,0,"linesPerFrame");
  linesPerFrame = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("linesPerFrame: %d\n",linesPerFrame);

  propVal = mxGetProperty(resonantAcqObject,0,"multiChannel");
  isMultiChannel = (bool) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("isMultiChannel: %d\n",isMultiChannel);

  //Safety set (just in case numLoggingChannels isn't set by hAcq.)
  //TODO: Remove
  if (isMultiChannel)
    numLoggingChannels = 4;
  else
    numLoggingChannels = 1;

  propVal = mxGetProperty(resonantAcqObject,0,"numLoggingChannels");
  numLoggingChannels = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("numLoggingChannels: %d\n",numLoggingChannels);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingChannelsArray");
  memcpy(loggingChannelsArray, (double*) mxGetPr(propVal), sizeof(double) * numLoggingChannels);
  mxDestroyArray(propVal);

  propVal = mxGetProperty(resonantAcqObject,0,"frameTagging");
  frameTagging = (bool) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("frameTagging: %d\n",frameTagging);

  // frame Size in different units
  propVal = mxGetProperty(resonantAcqObject,0,"frameSizePixels");
  frameSizePixels = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("frameSizePixels: %d\n",frameSizePixels);

  propVal = mxGetProperty(resonantAcqObject,0,"frameSizeBytes");
  frameSizeBytes = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("frameSizeBytes: %d\n",frameSizeBytes);

  propVal = mxGetProperty(resonantAcqObject,0,"frameSizeFifoElements");
  frameSizeFifoElements = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("frameSizeFifoElements: %d\n",frameSizeFifoElements);

  propVal = mxGetProperty(resonantAcqObject,0,"FRAME_TAG_SIZE_BYTES");
  tagSizeBytes = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("tagSizeBytes: %d\n",tagSizeBytes);

  propVal = mxGetProperty(resonantAcqObject,0,"tagSizeFifoElements");
  tagSizeFifoElements = (size_t) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("tagSizeFifoElements: %d\n",tagSizeFifoElements);

  propVal = mxGetProperty(resonantAcqObject,0,"frameQueueCapacity");
  frameQueueCapacity = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("frameQueueCapacity: %d\n",frameQueueCapacity);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingAverageFactor");
  loggingAverageFactor = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("loggingAverageFactor: %d\n",loggingAverageFactor);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingEnable");
  loggingEnabled = (bool) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("loggingEnabled: %d\n",loggingEnabled);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingSlowStack");
  loggingSlowStack = (bool) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("loggingSlowStack: %d\n",loggingSlowStack);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingNumSlowStackSlices");
  loggingNumSlowStackSlices = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("loggingNumSlowStackSlices: %d\n",loggingNumSlowStackSlices);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingFileCounter");
  loggingFileCounter = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("loggingFileCounter: %d\n",loggingFileCounter);

  propVal = mxGetProperty(resonantAcqObject,0,"simulatedFramePeriod");
  simulatedFramePeriod = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("simulatedFramePeriod: %d\n",simulatedFramePeriod);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingFramesPerFile");
  loggingFramesPerFile = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("loggingFramesPerFile: %d\n",loggingFramesPerFile);
  CONSOLEPRINT("MATLAB Inf value: %d\n",inf);

  propVal = mxGetProperty(resonantAcqObject,0,"loggingFramesPerFileLock");
  loggingFramesPerFileLock = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("loggingFramesPerFileLock: %d\n",loggingFramesPerFileLock);

  propVal = mxGetProperty(resonantAcqObject,0,"displayDecimationFactor");
  displayDecimationFactor = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("displayDecimationFactor: %d\n",displayDecimationFactor);

  propVal = mxGetProperty(resonantAcqObject,0,"displayBatchingFactor");
  displayBatchingFactor = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("displayBatchingFactor: %d\n",displayBatchingFactor);

  propVal = mxGetProperty(resonantAcqObject,0,"framesPerAcquisition");
  framesPerAcquisition = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("framesPerAcquisition: %d\n",framesPerAcquisition);

  propVal = mxGetProperty(resonantAcqObject,0,"framesPerStack");
  framesPerStack = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("framesPerStack: %d\n",framesPerStack);

  propVal = mxGetProperty(resonantAcqObject,0,"acquisitionsPerAcquisitionMode");
  acquisitionsPerAcquisitionMode = (unsigned long) mxGetScalar(propVal);
  mxDestroyArray(propVal);

  CONSOLEPRINT("acquisitionsPerAcquisitionMode: %d\n",acquisitionsPerAcquisitionMode);

  // Logging File Name (with Path)
  char fileNameBuf[MAXFILENAMESIZE] = {'\0'};
  propVal = mxGetProperty(resonantAcqObject,0,"loggingFullFileName");
  if (propVal!=NULL) {
    mxGetString(propVal,fileNameBuf,MAXFILENAMESIZE);
    if (strlen(fileNameBuf)==0)
      sprintf_s(fileNameBuf,MAXFILENAMESIZE,"%s",DEFAULT_LOG_FILENAME);
    mxDestroyArray(propVal);
    propVal = NULL;
  } else {
    sprintf_s(fileNameBuf,MAXFILENAMESIZE,"%s",DEFAULT_LOG_FILENAME);
    CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingFullFileName' returned NULL!");
  }
  strcpy_s(loggingFullFileName,fileNameBuf);
  strcpy_s(loggingFullFileNameBase,fileNameBuf);
  CONSOLEPRINT("'loggingFullFileName' set to:%s\n",loggingFullFileName);

  // fileMode
  char fileModeStrBuf[8] = "wbn";
  propVal = mxGetProperty(resonantAcqObject,0,"loggingOpenModeString");
  if (propVal!=NULL) {
    mxGetString(propVal,fileModeStrBuf,8);
    mxDestroyArray(propVal);
    propVal = NULL;
  } else {
    // defaults to "wbn"
    CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingOpenModeString' returned NULL!");
  }
  strcpy_s(loggingOpenModeString,fileModeStrBuf);
  CONSOLEPRINT("'loggingOpenModeString' set to:%s\n",loggingOpenModeString);

  // header
  char headerStrArray[MAXIMAGEHEADERSIZE] = "Default header str";
  propVal = mxGetProperty(resonantAcqObject,0,"loggingHeaderString");
  if (propVal!=NULL) {
    mxGetString(propVal,headerStrArray,MAXIMAGEHEADERSIZE);
    mxDestroyArray(propVal);
    propVal = NULL;
  } else {
    // defaults to "Default..." etc
    CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingHeaderString' returned NULL!");
  }
  strcpy_s(loggingHeaderString,headerStrArray);
  CONSOLEPRINT("'loggingHeaderString' set to:%s\n",loggingHeaderString);
}

//void MatlabParams::setIsMultiChannel(int value){
//	CONSOLEPRINT("Setting isMultiChannel to: %d", value);
//	isMultiChannel = (bool) value;
//}
//
//void MatlabParams::setFifoNumber(uint32_t fifoNumber){
//	CONSOLEPRINT("Setting fpgaFifo to: %d",(uint32_t) fifoNumber);
//	fpgaFifo = fifoNumber;
//}
//
//void MatlabParams::setSession(NiFpga_Session sessionID){
//	CONSOLEPRINT("Setting session to: %d",(NiFpga_Session) sessionID);
//	fpgaSession = sessionID;
//}

void MatlabParams::setCallback(mxArray* mxCbk){
  if (callbackFuncHandle != NULL) {
    CONSOLEPRINT("callbackFuncHandle != NULL, destroying array callbackFunHandle.\n");
    mxDestroyArray(callbackFuncHandle);
    callbackFuncHandle = NULL;    
  }
  if(mxCbk == NULL) {
    CONSOLEPRINT("WARNING! configureCallback: 'frameAcquiredFcn' is NULL\n");
  } else if(!mxIsEmpty(mxCbk) && (mxGetClassID(mxCbk) != mxFUNCTION_CLASS)) {
    CONSOLEPRINT("WARNING! configureCallback: 'frameAcquiredFcn' is not a function handle\n");
  } else {
    CONSOLEPRINT("configureCallback: Setting callbackFunHandle to function specified.\n");

    callbackFuncHandle = mxDuplicateArray(mxCbk);
    mexMakeArrayPersistent(callbackFuncHandle);
  }
}




//--------------------------------------------------------------------------//
// MatlabParams.cpp                                                         //
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
