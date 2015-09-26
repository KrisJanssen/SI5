function ok = safeCall(errCode)
%SAFECALL Utility function for calls to DAQmx driver, displaying error information if error is encountered

persistent dummyString
if isempty(dummyString)
    dummyString = repmat('a',[1 512]);
end
if errCode
    [err,errString] = calllib(dabs.ni.daqmx.System.driverLib,'DAQmxGetErrorString',errCode,dummyString,length(dummyString));
    fprintf(2,'DAQmx ERROR: %s\n', errString);
    ok = false; %
else
    ok = true; %No error
end
end





%--------------------------------------------------------------------------%
% safeCall.m                                                               %
% Copyright © 2015 Vidrio Technologies, LLC                                %
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
