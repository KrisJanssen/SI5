function Voltage_On_Demand_Output()
%% Voltage On Demand Output
% This examples demonstrates an analog ouput, that is updated on demand

%% Parameters for the output
devName = 'Dev1'; % the name of the DAQ device as shown in MAX

% Channel configuration
physicalChannels = 0;   % a scalar or an array with the channel numbers
minVoltage = -10;       % channel input range minimum
maxVoltage = 10;        % channel input range maximum

% Generate data for output
outputData = 0:10;
outputDelay = 1;        %output delay in seconds

import dabs.ni.daqmx.*  % import the NI DAQmx adapter

try
    % create and configure the task
    hTask = Task('Task'); 
    hTask.createAOVoltageChan(devName,physicalChannels,[],minVoltage,maxVoltage);

    hTask.start();
    
    for data = outputData
        hTask.writeAnalogData(data);
        disp(['output ' num2str(data) 'V']);
        pause(outputDelay);
    end
    
    % clean up task 
    hTask.stop();
    delete(hTask);
    clear hTask;
    
    disp('Output Finished');
    
catch err % clean up task if error occurs
    if exist('hTask','var')
        delete(hTask);
        clear hTask;
    end
    rethrow(err);
end


%--------------------------------------------------------------------------%
% Voltage_On_Demand_Output.m                                               %
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
