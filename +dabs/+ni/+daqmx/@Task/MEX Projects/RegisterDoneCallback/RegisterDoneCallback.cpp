#include "RegisterXXXCallback.h"

//Matlab signature
//status = RegisterDoneCallback(taskObj,registerTF)
// registerTF: (OPTIONAL) Logical value indicating if 'true', to register the Done Event and, if 'false', to unregister the Done Event. If empty/omitted, value 'true' is assumed.
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	if (!mexIsLocked()) {
		mexLock();
		mexAtExit(cleanUp);
	}

#if DEBUG_MEX
	if (nrhs==3) {
		CBDStoreDebugDump();
		nlhs = 0;
		return;
	}
#endif

	//Parse input arguments to determine whether registration or unregistration is specified
	bool registerTF;
	TaskHandle taskID;
	parseGeneralInputs(nrhs, prhs, &registerTF, &taskID);
	bool isRegistered = CBDStoreIsRegistered(taskID);

	int32 status = -1;
	if (registerTF) {
		if (isRegistered) {
			mexErrMsgTxt("TaskID/Event combo already registered.");
		}

		const mxArray *taskObj = prhs[0];
		int32 (*funcPtr)(TaskHandle, int32, void*) = callbackWrapper;
		CallbackData *cbd = CBDCreate(taskObj,DONE_EVENT,"doneEventCallbacks",NULL,NULL);

		status = DAQmxRegisterDoneEvent(taskID, DAQmx_Val_SynchronousEventCallbacks, funcPtr, cbd);
		if (status==0) {
			//success
#if DEBUG_MEX
			mexPrintf("success");
#endif
			CBDStoreAddCallbackData(taskID,cbd);
		} else {
#if DEBUG_MEX
			mexPrintf("failure");
#endif
			CBDDestroy(cbd);
		}
	} else { // unregister
		CBDStoreRmCallbackData(taskID);
		status = DAQmxRegisterDoneEvent(taskID, DAQmx_Val_SynchronousEventCallbacks, 0, 0);
	}

	nlhs = 1;
	plhs[0] = mxCreateDoubleScalar(status);
}

//--------------------------------------------------------------------------//
// RegisterDoneCallback.cpp                                                 //
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
