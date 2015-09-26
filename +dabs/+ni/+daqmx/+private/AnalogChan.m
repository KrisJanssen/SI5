classdef AnalogChan < dabs.ni.daqmx.Channel
    %ANALOGCHAN An abstract DAQmx Analog Channel class
    
    
    properties (Constant, Hidden)
        physChanIDsArgValidator = @isnumeric; %PhysChanIDs arg must be numeric (or a cell array of such, for multi-device case)
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = AnalogChan(varargin) 
            % obj = AnalogChan(createFunc,task,deviceName,physChanIDs,chanNames,varargin) 
            obj = obj@dabs.ni.daqmx.Channel(varargin{:});
        end        
    end
    
    
    %% METHODS
    methods (Hidden)
        %TMW: This function is a regular method, rather than being static (despite having no object-dependence). This allows caller in abstract superclass to invoke it by the correct subclass version. 
        %%% This would not need to be a regular method if there were a simpler way to invoke static methods, without resorting to completely qualified names.
        function [physChanNameArray,chanNameArray] = createChanIDArrays(obj, numChans, deviceName, physChanIDs,chanNames)            
           
            [physChanNameArray,chanNameArray] = deal(cell(1,numChans));
            for i=1:numChans
                if ~isnumeric(physChanIDs)
                    error([class(obj) ':Arg Error'], ['Argument ''' inputname(4) ''' must be a numeric array (or cell array of such, for multi-device case)']);
                else
                    physChanNameArray{i} = [deviceName '/' lower(obj.typeCode) num2str(physChanIDs(i))];
                end
                if isempty(chanNames)
                    chanNameArray{i} = '';
                elseif ischar(chanNames)
                    if numChans > 1
                        chanNameArray{i} = [chanNames num2str(i)];
                    else 
                        chanNameArray{i} = chanNames;
                    end
                elseif iscellstr(chanNames) && length(chanNames)==numChans
                    chanNameArray{i} = chanNames{i};
                else
                    error(['Argument ''' inputname(5) ''' must be a string or cell array of strings of length equal to the number of channels.']);
                end
            end
        end
    end
    
end





%--------------------------------------------------------------------------%
% AnalogChan.m                                                             %
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
