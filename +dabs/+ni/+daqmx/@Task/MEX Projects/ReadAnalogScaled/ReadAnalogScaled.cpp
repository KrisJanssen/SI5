// ReadAnalogScaled.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"

#define MAXVARNAMESIZE 64

//Matlab signature
//[sampsRead, outputData] = ReadAnalogData(task, numSampsPerChan, outputVarOrSize, outputFormat, timeout)
//	task: A DAQmx.Task object handle
//	numSampsPerChan: Specifies number of samples per channel to read. If 'inf' or < 0, then all available samples are read, up to the size of the output array.
//	outputVarOrSize: Either name of preallocated MATLAB variable into which to store read data, or the size in samples of the output variable to create (to be returned as outputData argument).
//	outputFormat: One of 'native' or 'scaled', indicating native unscaled format and double scaled format, respectively
//  timeout: Time, in seconds, to wait for function to complete read. If 'inf' or < 0, then function will wait indefinitely.


//Gateway routine
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	//Read input arguments
	mxArray *task
	char outputFormat[10];
	char outputVarName[MAXVARNAMESIZE];
	int	outputVarSize;
	double timeout;
	int numSampsPerChan;

	task = prhs[0];
	numSampsPerChan = (int) mxGetScalar(prhs[1]);
	mxGetString(prhs[3], outputFormat, 10);
	timeout = mxGetScalar(prhs[4]);

	bool outputData = mxIsNumeric(prhs[2]);
	if outputData
		outputVarSize = mxGetScalar(prhs[2]);
	else
		mxGetString(prhs[2], outputVarName, MAXVARNAMESIZE);

	//Extract task properties
	TaskHandle taskID = (TaskHandle)mxGetProperty(task,0, "taskID");
	int dataInterleaved = (int)mxGetProperty(task,0,"dataInterleaved");
	mwClassID rawDataClass = (mxClassID)mxGetProperty(task,0,"rawDataClass");

	//Determine output data type
	mwClassID outputDataClass;

	if (strcmpi(outputFormat,"scaled"))
		outputDataClass = mxDOUBLE_CLASS;
	else
		outputDataClass = rawDataClass;
	
	//Determine output buffer/size (creating if needed)
	int numChannels;
	int totalNumSamples;
	mxArray *outputDataBuf;
	if (outputData)
	{
		DAQmxGetTaskNumChans(taskID, &numChannels);		
		outputDataBuf = mxCreateNumericMatrix(outputVarSize,numChannels,outputDataClass,mxREAL);
	}
	else
	{
		outputDataBuf = mexGetVariable("caller", outputVarName);
		outputVarSize = mxGetM(outputDataBuf);
	}

	//Read data 


		totalNumSamples = arraySizeInSamples * numChannels;


		int arraySizeInBytes = totalNumSamples * sizeof(int16);






	int dataInterleaved
	int numSampsPerChan;
}

//--------------------------------------------------------------------------//
// ReadAnalogScaled.cpp                                                     //
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
