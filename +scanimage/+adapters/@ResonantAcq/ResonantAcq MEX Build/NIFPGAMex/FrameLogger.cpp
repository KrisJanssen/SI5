#include "stdafx.h"
#include "FrameLogger.h"
#include <sstream>
#include <process.h>

//const char *FrameLogger::FRAME_TAG_FORMAT_STRING = "Frame Tag = %08d\n";
//const char *FrameLogger::FRAME_TAG_FORMAT_STRING = "Frame Tag = %16lu\n";
const char *FrameLogger::FRAME_TAG_FORMAT_STRING = "Frame Number = %16lu\nFrame Timestamp(s) = %25.9f\nAcq Trigger Timestamp(s) = %25.9f\nNext File Marker Timestamp(s) = %25.9f\nDC Overvoltage =%2u\n";


FrameLogger::FrameLogger(void) : 
fThread(0),
//fFrameQueue(NULL),
fTifWriter(new TifWriter()),
fAverageFactor(1),
fAveragingBuf(NULL),
fAveragingResultBuf(NULL),
fKillLoggingFlag(false),
fHaltLoggingFlag(false),
fFramesLogged(0),
//fFrameTagEnable(false),
fmp(MatlabParams::getInstance())
//fFrameDelay(0)
{
	CONSOLEPRINT("FrameLogger::FrameLogger...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	assert(fTifWriter!=NULL);

	fState = CONSTRUCTED;

	InitializeCriticalSection(&fLogfileRolloverCS);
}

FrameLogger::~FrameLogger(void)
{
	CONSOLEPRINT("FrameLogger::~FrameLogger...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	if (fThread!=0) {
		stopLoggingImmediately();
		// Could go stronger and use something like TerminateThread here.
	}

	//fFrameQueue = NULL; // FrameQueue not owned by this obj  
	if (fTifWriter!=NULL) {
		delete fTifWriter;
		fTifWriter = NULL;
	}

	deleteAveragingBuffers();

	DeleteCriticalSection(&fLogfileRolloverCS); // no way to check if this has been initted
}

//bool
//FrameLogger::getFrameTagEnable()
//{
//	CONSOLEPRINT("FrameLogger::getFrameTagEnable...\n");
//	return fFrameTagEnable;
//}

//void
//FrameLogger::setFrameTagProps(bool frameTagEnable,bool frameTagOneBased)
//{
//	CONSOLEPRINT("FrameLogger::setFrameTagProps...\n");
//	assert(fState<ARMED);
//	fFrameTagEnable = frameTagEnable;
//	fFrameTagOneBased = frameTagOneBased;
//}

void 
FrameLogger::configureImage(unsigned int averagingFactor,
							const char *imageDesc)
{
	CONSOLEPRINT("FrameLogger::configureImage...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState<ARMED);
	assert(averagingFactor>0);

	//fImageParams = ip;
	// ip.numChannelsAvailable, ip.numChannelsActive are not used in FrameLogger.
	assert(!fTifWriter->isTifFileOpen());

	//Handle frame tag case, if applicable -- prepend frame tag, pad image description
	std::string imageDescStr = imageDesc;
	if (fmp->frameTagging) {
		//Prepend frame tag
		char frameTagStr[FRAME_TAG_STRING_LENGTH+1]="0";
		sprintf_s(frameTagStr,FRAME_TAG_FORMAT_STRING,0,0.0,0.0,0.0,0); 
		imageDescStr.insert(0,frameTagStr);

		//Pad image description (allows for ease of modifying description contents without recomputing IFDs etc)
		imageDescStr.append(IMAGE_DESC_DEFAULT_PADDING,' ');
		//CONSOLEPRINT("SETTING DEFAULT HEADER TO: %s\n",imageDescStr.c_str());
	}

	//fTifWriter->configureImage(ip.imageWidth,ip.imageHeight,ip.bytesPerPixel,
	//	ip.numLoggingChannels,ip.signedData,imageDescStr.c_str());
	fTifWriter->configureImage((unsigned short) fmp->pixelsPerLine, (unsigned short) fmp->linesPerFrame,fmp->pixelSizeBytes,(unsigned short)fmp->numLoggingChannels,fmp->signedData,imageDescStr.c_str());
	fConfiguredImageDescLength = (unsigned int) imageDescStr.length();

	fAverageFactor = averagingFactor;
	this->deleteAveragingBuffers();

	if (fAverageFactor > 1) {
		//CONSOLEPRINT("fImP.fnp: %d. faB: %p. sizeof fab: %d\n",fImageParams.frameNumPixels,fAveragingBuf,(sizeof fAveragingBuf));
		fAveragingBuf = (double*) calloc(fmp->frameSizeBytes, sizeof(double));
		fAveragingResultBuf = (char*) calloc(fmp->frameSizeBytes, sizeof(char));
		assert(fAveragingBuf!=NULL);
		assert(fAveragingResultBuf!=NULL);
		zeroAveragingBuffers();
	}

	return;
}

// arm ensures that all configuration-related state is set
// properly. runtime state is not initialized until startLogging().
bool
FrameLogger::arm(void)
{
	CONSOLEPRINT("FrameLogger::arm...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);

	assert(fState==CONSTRUCTED || fState==ARMED);
	assert(fThread==0);

	bool tfSuccess = true;

	if (fmp->loggingQueue==NULL) { tfSuccess = false; }
	if (fTifWriter==NULL) { tfSuccess = false; }
	assert(!fTifWriter->isTifFileOpen());
	if (fmp->loggingQueue->recordSize()!=fmp->frameSizeBytes) { tfSuccess = false; }
	// assume fImageParams and fTifWriter agree
	if (fAverageFactor>1 && (fAveragingBuf==NULL || fAveragingResultBuf==NULL)) {
		tfSuccess = false;
	}

	fState = (tfSuccess) ? ARMED : CONSTRUCTED;

	return tfSuccess;  
}

void
FrameLogger::disarm(void)
{
	CONSOLEPRINT("FrameLogger::disarm...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	assert(fState==ARMED || fState==STOPPED);
	assert(fThread==0);
	fState = CONSTRUCTED;
}

void
//FrameLogger::startLogging(int frameDelay)
FrameLogger::startLogging(void)
{
	CONSOLEPRINT("FrameLogger::startLogging...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState==ARMED);
	assert(fThread==0);

	// pre-start state initializations
	//fFrameDelay = frameDelay;
	fKillLoggingFlag = false;
	fHaltLoggingFlag = false;
	fFramesLogged = 0; 

	//reset lastAcqTriggerTimestamp and lastNextFileMarkerTimestamp to zero so that the first file of the next acquisition does not roll over.
	fmp->lastAcqTriggerTimestamp = 0;
	fmp->lastNextFileMarkerTimestamp = 0;

	if (fAverageFactor > 1) {    
		zeroAveragingBuffers();
	}

  if (!fmp->loggingQueue->isEmpty()) {
		CONSOLEPRINT("FrameLogger: Input queue is nonempty, has size %d.\n", fmp->loggingQueue->size());
  }
	// If fFrameQueue is nonempty, that is bizzaro. Throw a msgbox
	//if (!fFrameQueue->isEmpty()) {

	//	// xxx this comes up in testing b/c of the
	//	// "start-logger-after-acq-started" thing, the messagebox might be
	//	// modal or something

	//	CONSOLEPRINT("FrameLogger: Input queue is nonempty, has size %d.\n",
	//		fFrameQueue->size());

	//	// char str[256];
	//	// sprintf_s(str,256,"FrameLogger: Input queue is nonempty, has size %d.\n",
	//	// 	    fFrameQueue->size());
	//	// MessageBox(NULL,str,"Warning",MB_OK);
	//}
	fThread = (HANDLE)_beginthreadex(NULL,0,FrameLogger::loggingThreadFcn,(LPVOID)this,0,NULL);
	assert(fThread!=0);
	fState = RUNNING;
}

bool 
FrameLogger::isLogging(void) const 
{
	CONSOLEPRINT("FrameLogger::isLogging...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	return fState==RUNNING;
}

void 
FrameLogger::stopLogging(void) 
{
	CONSOLEPRINT("FrameLogger::stopLogging...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState==RUNNING);
	CONSOLEPRINT("FrameLogger: fState is RUNNING \n");
	assert(fThread!=0);
	CONSOLEPRINT("FrameLogger: fthread != 0\n");

	fHaltLoggingFlag = true; 

	// Stop signal sent. Now wait for logging thread to terminate.

	DWORD retval = WaitForSingleObject(fThread,STOP_LOGGING_TIMEOUT_MILLISECONDS);
	switch (retval) {
	  case WAIT_OBJECT_0:
		  CONSOLEPRINT("FrameLogger::stopLogging WAIT_OBJECT_0...\n");
		  // logging thread completed.
		  {
			  BOOL b = CloseHandle(fThread);
			  assert(b!=0);
			  fThread = 0;
			  // other runtime state can remain as-is in STOPPED state. to start,
			  // will have to disarm + arm + startLogging.
		  }
		  fState = STOPPED;
		  break;

	  case WAIT_TIMEOUT:
	  case WAIT_ABANDONED:
	  case WAIT_FAILED:
	  default:
		  CONSOLEPRINT("FrameLogger::stopLogging HARD STOP!!\n");
		  // Try harder to stop logging.
		  stopLoggingImmediately(); 

		  assert(fState==STOPPED || fState==KILLED);

		  if (fState==STOPPED) {
			  CONSOLEPRINT("FrameLogger: Logger could not finish processing. %d frames were unlogged.\n", fmp->loggingQueue->size());
			  // stopImmediately succeeded, which means everything is okay, but
			  // that we didn't finish logging.
			  //char str[256];
			  //sprintf_s(str,256,"FrameLogger: Logger could not finish processing. %d frames were unlogged.\n", fmp->loggingQueue->size());
			  //MessageBox(NULL,str,"Warning",MB_OK);
		  }

		  break;
	}
}

void
FrameLogger::stopLoggingImmediately(void)
{
	CONSOLEPRINT("FrameLogger::stopLoggingImmediately...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState==RUNNING);
	assert(fThread!=0);

	fKillLoggingFlag = true; 

	DWORD retval = WaitForSingleObject(fThread, STOP_LOGGING_TIMEOUT_MILLISECONDS);
	switch (retval) {
		case WAIT_OBJECT_0:
			// logging thread stopped.
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
			// stop immediately failed; we are hosed
			{
				CONSOLEPRINT("FrameLogger: Unable to stop logger. Please report this error to the ScanImage team.\n");
				//char str[256];
				//sprintf_s(str,256,"FrameLogger: Unable to stop logger. Please report this error to the ScanImage team.\n");
				//MessageBox(NULL,str,"Error",MB_OK);
			}
			fState = KILLED; // FrameLogger will be unusable in this state
			break;
	}
}

unsigned long
FrameLogger::getFramesLogged(void) const
{
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	return fFramesLogged;
}

void
FrameLogger::debugString(std::string &s) const
{
	std::ostringstream oss;
	oss << "--FrameLogger--" << std::endl;
	oss << "State Thread TifWriterFileOpen fAvFactor: " 
		<< fState << " " << fThread << " " 
		<< fTifWriter->isTifFileOpen() << " " 
		<< fAverageFactor << std::endl;
	oss << "KillLoggingFlag HaltLoggingFlag FramesLogged: "
		<< fKillLoggingFlag << " "
		<< fHaltLoggingFlag << " " 
		<< fFramesLogged << std::endl;

	s.append(oss.str());
}

void
FrameLogger::updateLogFile()
{
	EnterCriticalSection(&fLogfileRolloverCS);
	//CONSOLEPRINT("FrameLogger: rolling over file (fname %s).\n",fmp->loggingFullFileName);
	if (fTifWriter->isTifFileOpen()) {
		fTifWriter->closeTifFile();
	}
	if (!fTifWriter->openTifFile(fmp->loggingFullFileName,fmp->loggingOpenModeString)) {
		CONSOLEPRINT("FrameLogger: Error opening file %s. Aborting logging.\n",fmp->loggingFullFileName);
	}       
	LeaveCriticalSection(&fLogfileRolloverCS);
}

//unsigned int WINAPI FrameLogger::loggingThreadFcn(LPVOID userData)
unsigned __stdcall FrameLogger::loggingThreadFcn( void* userData )
{
	CONSOLEPRINT("FrameLogger::loggingThreadFcn...\n");
	FrameLogger *obj = static_cast<FrameLogger*>(userData);

	unsigned long localFrameTag;

	//Instantiate the MatlabParams singleton.
	MatlabParams* fmpThread = MatlabParams::getInstance();
	const int16_t* sourceArray;
	//New timestamp values added 4/16/14
	uint16_t fpgaPlaceHolder;
	uint64_t fpgaFrameTimestamp;
	uint64_t fpgaAcqTriggerTimestamp;
	uint64_t fpgaNextFileMarkerTimestamp;
	bool rolloverOnNextFrameFlag = false;

	while (1) {
		if (obj->fKillLoggingFlag) {
			CONSOLEPRINT("FrameLogger: KILL LOGGING FLAG: %d\n",obj->fKillLoggingFlag);
			break;
		}
		if (obj->fHaltLoggingFlag && fmpThread->loggingQueue->isEmpty()) {
			CONSOLEPRINT("FrameLogger: HALT LOGGING FLAG: %d, LOGGING QUEUE EMPTY? %d\n",obj->fHaltLoggingFlag,(int) fmpThread->loggingQueue->isEmpty());
			break;
		}

		// Write frame to TIF file
		if (fmpThread->loggingQueue->size() >= (unsigned int) (fmpThread->frameDelay + 1) || (obj->fHaltLoggingFlag && !fmpThread->loggingQueue->isEmpty())) {
			//			CONSOLEPRINT("Framelogger: Writing frame to TIF file...\n");
			//		    CONSOLETRACE();
			assert(obj->fTifWriter->isTifFileOpen());

			// Increment local Frame Counter (which is reset for every Acq)
			CONSOLEPRINT("localFrameCounter: %d\n",obj->localFrameCounter);
			obj->localFrameCounter++;

			// update local tag if tagging is enabled.
			if (fmpThread->frameTagging) {
				//First check to see if a file rollover must occur due to a next file trigger event on the previous frame.
				if (rolloverOnNextFrameFlag)
				{
					CONSOLEPRINT("rolloverOnNextFrameFlag == TRUE, checking to see if rollover should occur now or be deferred...\n");
					if ((fmpThread->framesPerStack == 0) || ((fmpThread->framesPerStack > 0) && (obj->localFrameCounter % fmpThread->framesPerStack == 0)))
					{						
	   	  		 	    CONSOLEPRINT("We have completed FastZ Volume or automatic rollover.\n");
						obj->rolloverLogFile(true);
						rolloverOnNextFrameFlag = false;
					}
				}

				// ****** BEGIN FRAME TAG DECODING LOGIC *******
				//Get the pointer to the first element of the current frame.
				sourceArray = (const int16_t*)(fmpThread->loggingQueue->front_unsafe());
				frameTag_t tempTag;
				//Cast the pointer to the tag of the current frame into the frameTag_t type for access to the Frame Tag Data.
				tempTag = *(frameTag_t*)(sourceArray + (fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2);
				localFrameTag = tempTag.fpgaTotalAcquiredRecords;
				fpgaPlaceHolder = tempTag.fpgaPlaceHolder;
				fpgaFrameTimestamp = tempTag.fpgaFrameTimestamp;
				fpgaAcqTriggerTimestamp = tempTag.fpgaAcqTriggerTimestamp;
				fpgaNextFileMarkerTimestamp = tempTag.fpgaNextFileMarkerTimestamp;

				if ((fpgaAcqTriggerTimestamp == 0) && (localFrameTag == 1))
				{
					CONSOLEPRINT("FrameLogger: FIRST FRAME!\n");
					// The very first frame being logged.
					// Set the timestamp offset to equal the frame timestamp. This offset is used to then correct all timestamp values for this acquisition.
					fmpThread->frameTimestampOffset = tempTag.fpgaFrameTimestamp;
					// Set the "last" next file marker stamp to the current frame's fpgaNextFileMarkerTimestamp.
					fmpThread->lastNextFileMarkerTimestamp = tempTag.fpgaNextFileMarkerTimestamp;
					//Create the first logging file.
					obj->rolloverLogFile(false);
					rolloverOnNextFrameFlag = false;
					obj->localFrameCounter = 0; // Reset local frame counter if this is the first frame of an acquisition.
				} else if ((fmpThread->loggingFramesPerFile != fmpThread->inf) && (fmpThread->loggingFramesPerFile > 0))
				{
					if (obj->localFrameCounter % (unsigned long) fmpThread->loggingFramesPerFile == 0){
						obj->rolloverSubLogFile();
					}
				}
				// ****** END FRAME TAG DECODING LOGIC *******

				// ****** BEGIN SLOW STACK LOGGING LOGIC *****
				if (fmpThread->loggingSlowStack && (localFrameTag != 1) && (localFrameTag % (fmpThread->framesPerAcquisition * fmpThread->loggingNumSlowStackSlices) == 0)) {
                    // If we have captured the last frame in a stack, then roll over the log file.
					CONSOLEPRINT("END OF SLOW STACK. ROLLING OVER LOG FILE...\n");
					rolloverOnNextFrameFlag = true;
				}
				// ****** END SLOW STACK LOGGING LOGIC *****

				// ****** BEGIN DETECTION OF FILE MARKER TIMESTAMP AND ACQUISITION TIMESTAMP LOGIC **********
				//Check to see if the next file marker trigger was set.
				if (fpgaNextFileMarkerTimestamp != fmpThread->lastNextFileMarkerTimestamp)
				{
					//CONSOLEPRINT("fpgaNextFileMarkerTimestamp != fmpThread->lastNextFileMarkerTimestamp\n");
					//If the next file marker trigger was detected, update the last next File marker Timestamp to the current one.
					fmpThread->lastNextFileMarkerTimestamp = fpgaNextFileMarkerTimestamp;
					//Check to see if the trigger occurred before or after the current captured frame.
					//Do not roll over the file during slow stack acquisitions.
					if (!fmpThread->loggingSlowStack)
					{
						if (fpgaFrameTimestamp < fpgaNextFileMarkerTimestamp)
						{
							// The most common case: The trigger occurred some time during the current frame. Put the current frame into the current log file,
							// then put the next frame into the next log file.
							// Signal to the routine to rollover after the current frame is written to disk.
							rolloverOnNextFrameFlag = true;
							CONSOLEPRINT("NEXTFILEMARKER SETTING ROLLOVERONNEXTFRAMEFLAG!\n");
						} else
						{
							// The less common case: The trigger occurred either at the time same time or before the current frame.
							// Manually roll the log file over and put the current frame into the next log file.
							CONSOLEPRINT("NEXTFILEMARKER MANUALLY ROLLING OVER THE TRIGGER FILE!\n");
							CONSOLEPRINT("Checking to see if we are in the middle of a FastZ Acquisition...\n");
							if ((fmpThread->framesPerStack == 0) || ((fmpThread->framesPerStack > 0) && (obj->localFrameCounter % fmpThread->framesPerStack == 0)))
							{						
								CONSOLEPRINT("We have completed FastZ Volume or automatic rollover.\n");
								obj->rolloverLogFile(true);
								rolloverOnNextFrameFlag = false;
							}
						}
					}
				}
				// CONSOLEPRINT("fpgaFrameTimestamp: %d, fpgaAcqTriggerTimestamp: %d, fpgaNextFileMarkerTimestamp: %d, fmpThread->lastAcqTriggerTimestamp: %d\n",fpgaFrameTimestamp,fpgaAcqTriggerTimestamp,fpgaNextFileMarkerTimestamp,fmpThread->lastAcqTriggerTimestamp);

				//Check to see if the acquisition timestamp was changed.
				if (fpgaAcqTriggerTimestamp != fmpThread->lastAcqTriggerTimestamp)
				{
					//CONSOLEPRINT("fpgaAcqTriggerTimestamp != fmpThread->lastAcqTriggerTimestamp\n");
					//If the acquisition timestamp change was detected, update the last acquisition timestamp to the current one.
					fmpThread->lastAcqTriggerTimestamp = fpgaAcqTriggerTimestamp;
					//Check to see if the acquisition timestamp change occurred before or after the current captured frame.
					//Do not roll over the file during slow stack acquisitions.
					if (!fmpThread->loggingSlowStack)
					{
						if (fpgaFrameTimestamp < fpgaAcqTriggerTimestamp)
						{
							// The most common case: The trigger occurred some time during the current frame. Put the current frame into the current log file,
							// then put the next frame into the next log file.
							// Signal to the routine to rollover after the current frame is written to disk.
							rolloverOnNextFrameFlag = true;
							CONSOLEPRINT("ACQTRIGGERTIMESTAMP SETTING ROLLOVERONNEXTFRAMEFLAG!\n");
						} else
						{
							// The less common case: The trigger occurred either at the time same time or before the current frame.
							// Manually roll the log file over and put the current frame into the next log file.
							CONSOLEPRINT("ACQTRIGGERTIMESTAMP MANUALLY ROLLING OVER THE TRIGGER FILE!\n");
							obj->rolloverLogFile(true);
					        rolloverOnNextFrameFlag = false;
						}
					}
				}
				// ****** END DETECTION OF FILE MARKER TIMESTAMP AND ACQUISITION TIMESTAMP LOGIC **********
			}

			// Three threads access fFrameQueue: this thread (the logging
			// thread), the frameCopier thread (doing pushes only), and
			// the MATLAB exec thread (acting as the controller). Use
			// front_checkout/checkin to protect against controller eg
			// initting the queue while we read (unlikely but conceivable).

			//CONSOLETRACE();
			const void *framePtr = fmpThread->loggingQueue->front_checkout();

			const char *charFramePtr = static_cast<const char*>(framePtr);

			if (obj->fAverageFactor==1) {
				// no averaging.
				//CONSOLETRACE();
				if (fmpThread->frameTagging) {
					if (!obj->updateFrameTag(charFramePtr,localFrameTag,fpgaPlaceHolder,fpgaFrameTimestamp,fpgaAcqTriggerTimestamp,fpgaNextFileMarkerTimestamp)) {
						CONSOLETRACE();

						// This break will exit loggingThreadFcn. Subsequent calls
						// to stopLogging or stopLoggingImmediately will "succeed".
						break; 
					}          
				}
				//CONSOLETRACE();

				// If this hangs/throws, front_checkin will never be called
				// and we will lock up.
				//CONSOLETRACE();
				obj->fTifWriter->writeFramesForAllChannels(charFramePtr,(unsigned int) fmpThread->frameSizeBytes * (unsigned short) fmpThread->numLoggingChannels);
				//CONSOLETRACE();
				fmpThread->loggingQueue->front_checkin();
				//CONSOLETRACE();
			} else {

				int modVal = obj->fFramesLogged % obj->fAverageFactor;
				if (modVal == 0) {
					obj->zeroAveragingBuffers();
				}
				bool computeAverageTF = (modVal + 1 == obj->fAverageFactor);

				obj->addToAveragingBuffer(framePtr);

				if (fmpThread->frameTagging && computeAverageTF) {
					if (!obj->updateFrameTag(charFramePtr,localFrameTag,fpgaPlaceHolder,fpgaFrameTimestamp,fpgaAcqTriggerTimestamp,fpgaNextFileMarkerTimestamp)) {
						// This break will exit loggingThreadFcn. Subsequent calls
						// to stopLogging or stopLoggingImmediately will "succeed".
						break; 
					}      
				}

				fmpThread->loggingQueue->front_checkin();
				framePtr = NULL;

				if (computeAverageTF) {
					obj->computeAverageResult();

					obj->fTifWriter->writeFramesForAllChannels(obj->fAveragingResultBuf,(unsigned int) fmpThread->frameSizeBytes * (unsigned short) fmpThread->numLoggingChannels);
				}
			}

			fmpThread->loggingQueue->pop_front();
			obj->fFramesLogged++;
		}

		Sleep(0); //relinquish thread
	}

	CONSOLEPRINT("FrameLogger: exiting logging thread.\n");

	if (obj->fTifWriter->isTifFileOpen()) {
		obj->fTifWriter->closeTifFile();
	}

	return 0;
}

//Calling this function updates the loggingFileCounter, closes the currently TIF file being logged, and opens a new TIF file to write frames to.
void
FrameLogger::rolloverLogFile(bool incrementFileCounter)
{
	if (incrementFileCounter)
		fmp->loggingFileCounter++;
	// If loggingFramesPerFile is set to a non-Infinite value in Matlab, then all logging files use the subcounter.
	fmp->loggingFileSubCounter = 1;
	localFrameCounter = 0;
	if ((fmp->loggingFramesPerFile != fmp->inf) && (fmp->loggingFramesPerFile > 0))
		sprintf_s(fmp->loggingFullFileName,"%s_%03u_%03u.tif",fmp->loggingFullFileNameBase,fmp->loggingFileCounter,fmp->loggingFileSubCounter);
	else
		sprintf_s(fmp->loggingFullFileName,"%s_%03u.tif",fmp->loggingFullFileNameBase,fmp->loggingFileCounter);
	updateLogFile();
}

void
FrameLogger::rolloverSubLogFile(void)
{
	// If loggingFramesPerFile is set to a non-Infinite value in Matlab, then all logging files use the subcounter.
	fmp->loggingFileSubCounter++;
    sprintf_s(fmp->loggingFullFileName,"%s_%03u_%03u.tif",fmp->loggingFullFileNameBase,fmp->loggingFileCounter,fmp->loggingFileSubCounter);
	updateLogFile();
}

bool
//FrameLogger::updateFrameTag(const char *framePtr, unsigned long frameTag)
FrameLogger::updateFrameTag(const char *framePtr, unsigned long frameTag, uint16_t fpgaPlaceHolder, uint64_t fpgaFrameTimestamp, uint64_t fpgaAcqTriggerTimestamp, uint64_t fpgaNextFileMarkerTimestamp)
{
	char frameTagStr[FRAME_TAG_STRING_LENGTH+1] = "0";
	// Timestamps converted to milliseconds.
	bool fpgaDCOvervoltage = ( fpgaPlaceHolder & ( (uint16_t) (1) << 2) ) > 0; // get the third bit of the placeholder
	double fpgaFrameTimestampMS = ((double) fpgaFrameTimestamp - (double) fmp->frameTimestampOffset) / fmp->sampleRate;
	double fpgaAcqTriggerTimestampMS = ((double) fpgaAcqTriggerTimestamp - (double) fmp->frameTimestampOffset) / fmp->sampleRate;
	double fpgaNextFileMarkerTimestampMS = ((double) fpgaNextFileMarkerTimestamp - (double) fmp->frameTimestampOffset) / fmp->sampleRate;

	//CONSOLEPRINT("Frame Tag = %16lu, Frame Timestamp(s) = %25.9f, Acq Trigger Timestamp(s) = %25.9f, Next File Marker Timestamp(s) = %25.9f, DC Overvoltage = %u\n",
	//	frameTag, fpgaFrameTimestampMS, fpgaAcqTriggerTimestampMS, fpgaNextFileMarkerTimestampMS,fpgaDCOvervoltage);
	int numWritten = sprintf_s(frameTagStr, FRAME_TAG_FORMAT_STRING, frameTag, fpgaFrameTimestampMS, fpgaAcqTriggerTimestampMS, fpgaNextFileMarkerTimestampMS,fpgaDCOvervoltage);
	//int numWritten = sprintf_s(frameTagStr,FRAME_TAG_STRING_LENGTH+1,"Frame Tag = %08d",frameTag);  

	if (numWritten == FRAME_TAG_STRING_LENGTH) {
		fTifWriter->modifyImageDescription(0,frameTagStr,FRAME_TAG_STRING_LENGTH);
		return true;
	} else {
		char str[2048];
		sprintf_s(str,2048,"FrameLogger: Error writing frame tag. Wrote %d chars to make string: %s. (should have written %d). Aborting logging.\n",numWritten,frameTagStr,FRAME_TAG_STRING_LENGTH);
		MessageBox(NULL,str,"Error",MB_OK);
		return false;
	}
}

void FrameLogger::zeroAveragingBuffers(void)
{
	assert(fAveragingBuf!=NULL);
	for (size_t i=0;i<(fmp->frameSizeBytes);i++) {
		fAveragingBuf[i] = 0.0;
	}
}

void FrameLogger::addToAveragingBuffer(const void *p)
{
	assert(fAveragingBuf!=NULL);
	assert(sizeof(short)==2);
	assert(sizeof(long)==4);

	for (int i=0;i<(fmp->frameSizePixels*fmp->numLoggingChannels);i++) {
		switch (fmp->pixelSizeBytes) {
	case 1:
		fAveragingBuf[i] += (double) (*((char*)p + i)); // ((char*)p)[i]
		break;
	case 2:
		fAveragingBuf[i] += (double) (*((short*)p + i)); // etc
		break;
	case 4:
		fAveragingBuf[i] += (double) (*((long*)p + i));
		break;
	default:
		assert(false);
		}
	}
}

void FrameLogger::computeAverageResult(void)
{
	for (int i=0;i<(fmp->frameSizePixels * fmp->numLoggingChannels);++i) {
		double avVal = fAveragingBuf[i] / (double)fAverageFactor;
		switch (fmp->pixelSizeBytes) {
	case 1:
		((char *)fAveragingResultBuf)[i] = (char)avVal;
		break;
	case 2:				
		((short *)fAveragingResultBuf)[i] = (short)avVal;
		break;
	case 4:
		((long *)fAveragingResultBuf)[i] = (long)avVal;
		break;
	default:
		assert(false);
		}
	}
}

void
FrameLogger::deleteAveragingBuffers(void) 
{
	fAveragingBuf = (double *) trueFree(fAveragingBuf);
	fAveragingResultBuf = (char *) trueFree(fAveragingResultBuf);
}

void*
FrameLogger::trueFree(void * fMem)
{
	if (fMem != NULL)
		free(fMem);
	return NULL;
}

//**********************************************************************************
//This should only be called once - at the beginning of a grab.

void
FrameLogger::configureLogFile(void)
{
	CONSOLEPRINT("FrameLogger::configureLogFile...\n");
	CONSOLETRACE();

	assert(!isLogging());

	CONSOLEPRINT("FrameLogger::configureLogFile - ensuring disarmed...\n");
	ensureDisarmed();
	CONSOLEPRINT("FrameLogger::configureLogFile - calling configureImage...\n");
	configureImage((unsigned int) fmp->loggingAverageFactor,fmp->loggingHeaderString);
}

void
FrameLogger::ensureDisarmed(void)
{
	if (isLogging()) {
		CONSOLEPRINT("Logger was logging, stopping.\n");
		stopLogging();
	}
	disarm();
}

//--------------------------------------------------------------------------//
// FrameLogger.cpp                                                          //
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
