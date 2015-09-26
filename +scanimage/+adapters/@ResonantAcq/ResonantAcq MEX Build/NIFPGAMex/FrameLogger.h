#pragma once

#include <deque>
#include "StateModelObject.h"
#include "AbstractConsumerQueue.h"
#include "TifWriter.h"
#include "MatlabParams.h"

//forward declarations
class MatlabParams;
class FrameQueue;

/*
FrameLogger

FrameLogger is a model FrameActor. It polls an input FrameQueue and
processes frames as they show up. This is done in a separate
processing thread.

Responsibilities.
* Logging-level averaging
* Streaming to disk

Thread-safety.  
The threading model is similar to FrameCopier. The usage model
involves three threads:
* Controller thread. This thread calls init/configuration methods,
starts/stops processing, etc. There should only be one such
thread, ie only one thread should make calls to the FrameLogger
public API.
* Processing thread. FrameLogger spawns this thread to perform its
duties. Averaging and streaming to TIF files is done in this thread.
* Input-Queue-Producer thread. In general, another thread acts as the
producer for the input queue.

State model.
The state model here is the same as for FrameCopier, except that 
there currently is no PAUSED state. While pausing the logger is reasonable 
in theory, at the moment doing so will quickly result in dropped logging 
frames.  
*/
class FrameLogger : public StateModelObject {

public:

	FrameLogger(void);

	~FrameLogger(void);

	/// Initialization methods (setup/config)
	/// These methods cannot be called on a FrameLogger at state ARMED
	/// or above.

	// Configure image parameters.
	//void configureImage(const ImageParameters &ip,
	//      unsigned int averagingFactor,
	//      const char *imageDesc);
	void configureImage(unsigned int averagingFactor, const char *imageDesc);

	/// Arm

	// Precondition: CONSTRUCTED or ARMED (double-arming has no effect)
	// Postcondition: ARMED if successful, CONSTRUCTED otherwise.
	//
	// Return value is true on success, false otherwise.
	bool arm(void);

	// Precondition: ARMED or STOPPED.
	// Postcondition: CONSTRUCTED
	void disarm(void);


	/// Start/stop logging. 

	// Resets counters and logging will begin when data is put into
	// frame queue.
	// 
	// Precondition: ARMED 
	// Postcondition: RUNNING
	//void startLogging(int frameDelay);
	void startLogging(void);

	// Equivalent to state==RUNNING.
	bool isLogging(void) const;

	// Stop logging as soon as the input queue is emptied. This blocks
	// until logging is stopped.
	// 
	// Precondition: RUNNING 
	// Postcondition: STOPPED
	//
	// Note that to start logging again from a STOPPED state requires
	// calls to disarm() and then arm() before startLogging() can be called
	// again. This ensures clean initialization of all necessary state.
	void stopLogging(void);

	// Stop logging asap (input queue is not necessarily emptied). This
	// blocks until logging is stopped.
	//
	// Precondition: RUNNING
	// Postcondition: STOPPED
	void stopLoggingImmediately(void);

	// This can be called in any state.
	unsigned long getFramesLogged(void) const;

	/// Misc

	// Append debug info to s.
	void debugString(std::string &s) const;

	void configureLogFile(void);
	void ensureDisarmed(void);
	void updateLogFile(void);
    void *trueFree(void * fMem);

	#pragma pack(1)
	typedef struct frameTag {
		int16_t  fpgaTagIdentifier;
		uint16_t fpgaPlaceHolder;
		uint32_t fpgaTotalAcquiredRecords;
		uint64_t fpgaFrameTimestamp;
		uint64_t fpgaAcqTriggerTimestamp;
		uint64_t fpgaNextFileMarkerTimestamp;
	} frameTag_t; 

private:
	MatlabParams* fmp;
	static unsigned int WINAPI loggingThreadFcn(LPVOID);

	void zeroAveragingBuffers(void);
	void addToAveragingBuffer(const void *p);
	void computeAverageResult(void);
	void deleteAveragingBuffers(void);
	void rolloverLogFile(bool incrementFileCounter);
	void rolloverSubLogFile(void);
	bool updateFrameTag(const char *framePtr, unsigned long frameTag, uint16_t fpgaPlaceHolder, uint64_t fpgaFrameTimestamp, uint64_t fpgaAcqTriggerTimestamp, uint64_t fpgaNextFileMarkerTimestamp);

	FrameQueue* fMatlabQ;

private:
	static const DWORD STOP_LOGGING_TIMEOUT_MILLISECONDS = 5000; // 5 seconds
	static const char* FRAME_TAG_FORMAT_STRING; //Allow up to 10 million
//	static const unsigned int FRAME_TAG_STRING_LENGTH = 8 + 13; //Allow for 'Frame Tag = \n' at start
	static const unsigned int FRAME_TAG_STRING_LENGTH = 209;
	static const unsigned int IMAGE_DESC_DEFAULT_PADDING = 100;

	HANDLE fThread;

	// FrameQueue has mutable state, so calls to it probably won't be
	// optimized away. In particular for example we want isEmpty() not
	// to be cached.
	TifWriter *fTifWriter;

	//ImageParameters fImageParams;
	unsigned int fAverageFactor;
	double *fAveragingBuf; // one double for every pixel in a frame
	char *fAveragingResultBuf; // one byte/char for every byte in a frame
	unsigned long int localFrameCounter; // used for counting frames between acqs.

	// runtime state
	bool volatile fKillLoggingFlag;
	bool volatile fHaltLoggingFlag;

	CRITICAL_SECTION fLogfileRolloverCS;

	unsigned long fFramesLogged;

	unsigned int fConfiguredImageDescLength; // length of image description specified at last configureImage()
};


//--------------------------------------------------------------------------//
// FrameLogger.h                                                            //
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
