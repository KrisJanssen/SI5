// DriverTest1.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"


int _tmain(int argc, _TCHAR* argv[])
{
	TaskHandle task;
	int acqTime = 6;
	float64 sampleRate = 500000.0;
	float64 linePeriod = .002;
	int lineSamples = (int)(linePeriod * sampleRate);
	int numLines = (int) (acqTime / (lineSamples/sampleRate));
	int acqSamples = numLines * lineSamples;
	int32 sampsWritten;
	bool32 taskDone;


	//Create the task
	DAQmxCreateTask("a task", &task);

	//Add AO channels
	DAQmxCreateAOVoltageChan(task, "Dev1/ao0", "", -10, 10, DAQmx_Val_Volts, NULL);

	//Configure timing
	DAQmxCfgSampClkTiming(task, NULL, sampleRate, DAQmx_Val_Rising, DAQmx_Val_FiniteSamps, acqSamples);

	//Write output data
	float64 *outputData = (float64*) calloc(acqSamples, sizeof(float64));
	for (int i=0;i<numLines;i++)
	{
		for (int j=0;j<lineSamples;j++)
		{
			outputData[i*lineSamples + j] = ((float64) j/(float64)lineSamples) * 10.0;
		}
	}
	DAQmxWriteAnalogF64(task, acqSamples, false, 10.0, DAQmx_Val_GroupByChannel, outputData, &sampsWritten, NULL);
	printf("Wrote %d samples of data!\n", sampsWritten);
	printf("Sample #33: %g\n", outputData[32]);
	printf("Sample #121: %g\n", outputData[120]);
	printf("Sample #6032: %g\n", outputData[6031]);


	//Start Task
	DAQmxStartTask(task);
	printf("Started task...\n");

	while (true)
	{
		DAQmxIsTaskDone(task,&taskDone);
		if (taskDone)
			break;
		else
			Sleep(1000);
	}

	//Clear Task
	DAQmxClearTask(task);





	
	return 0;
}



//--------------------------------------------------------------------------//
// DriverTest1.cpp                                                          //
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
