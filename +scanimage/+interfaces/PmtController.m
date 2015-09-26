classdef PmtController < handle
    % Abstract class describing an interface to a PMT controller
    % one PMT controller can manage multiple PMTs
    properties (Abstract, SetAccess = protected)
        numPmts;                 % [numerical] number of PMTs managed by the PMT controller
        pmtNames;                % Cell array of strings with a short name for each PMT
    end
    
    properties (Abstract)
        pmtsStatusUpdatedFcn;    % [function_handle] called after the PMT controller status changed
        pmtsStatusLastUpdated;   % time of last pmt status update
        
        pmtsPowerOn;             % [logical]   array containing power status for each PMT 
        pmtsGain;                % [numerical] array containing gain setting for each PMT
        pmtsTripped;             % [logical]   array containing trip status for each PMT
    end
    
    properties (Abstract, Dependent)
        acqStatusUpdateInterval; % rate at which to update the pmt status during an acquisition
    end
    
    methods (Abstract)
        pmtsUpdateStatus(obj);   % requests the PMT controller to update its properties after the update, obj.statusUpdateFcn() is executed
    end
end



%--------------------------------------------------------------------------%
% PmtController.m                                                          %
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
