function tf = checkForTask(taskname, del, daqmxsys)
%HACK Accessory function for scanimage.util.priv.safeCreateTask (which is a HACK)
    
    if nargin < 3
        daqmxsys = dabs.ni.daqmx.System;
    end

    tasklist = daqmxsys.tasks;

    for i = 1:numel(tasklist)
        if strcmp(tasklist(i).taskName, taskname)
            tf = true;
            
            if(del)
                delete(tasklist(i));
            end
            
            return;
        end
    end
    
    tf = false;

end



%--------------------------------------------------------------------------%
% checkForTask.m                                                           %
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
