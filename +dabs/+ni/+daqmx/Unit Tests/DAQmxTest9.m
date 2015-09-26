%Test of ability to register/unregister callbacks

import Devices.NI.DAQmx.*
global callbackStruct9

%% Digital Device/Done Callback Test
device = 'Dev4';
digLine = 1;
sampRate = 10000;
outputPattern = [0;1;0;1];
callbackName = 'test9Callback';

hSys = Devices.NI.DAQmx.System.getHandle();
delete(hSys.tasks);
%pcode(callbackName);

hCtr = Task('Counter Task');
hCtr.createCOPulseChanFreq(device,0,'',sampRate)
hCtr.cfgImplicitTiming('DAQmx_Val_ContSamps')
hCtr.start();

hTask = Task('DO Task');
hTask.createDOChan(device,['line' num2str(digLine)]);
hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',length(outputPattern),'Ctr0InternalOutput');
hTask.writeDigitalData(logical(outputPattern)); %Write once only

callbackFlag = true;
callbackStruct9.task = hTask;
callbackStruct9.stopInCallback = true;

while true
    
    if callbackFlag
        hTask.registerDoneEvent(callbackName);       
        dispString = 'on';
    else
        hTask.unregisterDoneEvent();
        dispString = 'off';
    end
    
    reply = input('Press any key to start or ''q'' to quit: ', 's');
    if strcmpi(reply,'q')
        break;
    else   
        disp(['Starting...(Callback ' dispString ')']);       
        hTask.start();
        pause(.1); %This prevents buglet where isTaskDone() will return TRUE if called too soon after starting...the /first/ time the Task is started.
    end
    
    if ~callbackFlag %Poll if the Done callback isn't registered
        while ~hTask.isTaskDone()
            pause(1);
        end
        hTask.stop();
    end
              
    callbackFlag = ~callbackFlag;
end
    
delete(hTask);

%% Digital Device/EveryN Callback Test
device = 'Dev4';
digLine = 1;
sampRate = 10000;
outputPattern = repmat([0;1;0;1],2500,1);
callbackName = 'test9Callback';
duration = 8; 
totalNumSamples = length(outputPattern) * duration;  %Assumes outputPattern/sampRate combine for 1 second 

hSys = Devices.NI.DAQmx.System.getHandle();
delete(hSys.tasks);
%pcode(callbackName);

hCtr = Task('Counter Task');
hCtr.createCOPulseChanFreq(device,0,'',sampRate)
hCtr.cfgImplicitTiming('DAQmx_Val_ContSamps')
hCtr.start();

hTask = Task('DO Task');
hTask.createDOChan(device,['line' num2str(digLine)]);
hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',totalNumSamples,'Ctr0InternalOutput');
hTask.writeDigitalData(logical(repmat(outputPattern,duration,1))); %Write once only %Note write must be enlarged to ensure that output buffer is larger than everyNSamples value!

hTask.everyNSamplesEvtCallbacks = callbackName;
everyNSamplesValues = [totalNumSamples/2 totalNumSamples/4 totalNumSamples/8 0];

iterationCounter = 0;
callbackStruct9.task = hTask;
callbackStruct9.stopInCallback = false;

while true
    
    idx = mod(iterationCounter,length(everyNSamplesValues))+1;
    newVal = everyNSamplesValues(idx);
    if newVal
        hTask.everyNSamples = newVal ; %Updates everyNSamples value, registering callback
    else
        hTask.unregisterEveryNSamplesEvent();
    end
    
    reply = input('Press any key to start or ''q'' to quit: ', 's');
    if strcmpi(reply,'q')
        break;
    else   
        disp(['Starting... (EveryNSamples =  ' num2str(newVal) ')']);       
        hTask.start();
        pause(.1); %This prevents buglet where isTaskDone() will return TRUE if called to soon after starting...the /first/ time the Task is started.
    end
    
    %Poll until Done
    while ~hTask.isTaskDone()
        pause(1);
    end
    hTask.stop();
                  
    iterationCounter = iterationCounter + 1;
end
    
delete(hTask);





%--------------------------------------------------------------------------%
% DAQmxTest9.m                                                             %
% Copyright � 2015 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 5 is licensed under the Apache License, Version 2.0            %
% (the "License"); you may not use any files contained within the          %
% ScanImage 5 release  except in compliance with the License.              %
% You may obtain a copy of the License at                                  %
% http://www.apache.org/licenses/LICENSE-2.0                               %
%                                                                          %
% Unless required by applicable law or agreed to in writing, software      %
% distributed under the License is distributed on an "AS IS" BASIS,        %
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. %
% See the License for the specific language governing permissions and      %
% limitations under the License.                                           %
%--------------------------------------------------------------------------%