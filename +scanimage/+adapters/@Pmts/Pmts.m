classdef Pmts < handle
%     %% ABSTRACT PROP REALIZATION (most.Model)
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = zlclInitPropAttributes();
%         mdlHeaderExcludeProps = {};
%     end
    
%     %% ABSTRACT PROPERTY REALIZATION (scanimage.subsystems.SubSystem)
%     properties (SetAccess = protected, Hidden)
%         numInstances = 0;
%         hPmtControllers = {};
%         internalSetFlag = false;
%         hTimer;
%     end
%     
%     properties (Constant, Hidden)
%         SUB_SYSTEM_NAME = 'Pmts';                          % [char array] short name describing functionality of subsystem e.g. 'Beams' or 'FastZ'
%         PROP_TRUE_LIVE_UPDATE = {'powersOn','gains','tripped'}; % Cell array of strings specifying properties that can be set while the subsystem is active
%         DENY_PROP_LIVE_UPDATE = {};                        % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
%         
%         FUNC_TRUE_LIVE_EXECUTION = {}; % Cell array of strings specifying functions that can be executed while the subsystem is active
%         DENY_FUNC_LIVE_EXECUTION = {};                     % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
%     end
%     
    
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
        hPmtControllers = {};
        hTimer;
        hModel;
        Mod2ContSet = 0;
    end
    
    %% Class Properties    
    properties (SetObservable,Transient,SetAccess = private)
        names;
    end
    
    properties (SetObservable,Transient)
        powersOn;
        tripped;
    end
    
    properties (SetObservable)
        gains;
    end
    
    %% Internal properties
    properties (Constant, Hidden)
        PMT_UPDATE_PERIOD = 1;
    end
    
    %% Lifecycle
    methods
        function obj = Pmts(hModel)
            obj.hModel = hModel;            
             
            obj.hTimer = timer('Name','PMT status update timer');
            obj.hTimer.ExecutionMode = 'fixedSpacing';
            obj.hTimer.Period = obj.PMT_UPDATE_PERIOD;
            obj.hTimer.TimerFcn = @obj.updateStatus;
            
            obj.initialize();
        end
        
        
        function initialize(obj)
            %              for i = 1:numel(obj.hModel.hPlugins)
            %                  hPlugin = obj.hModel.hPlugins{i};
            %                  if isa(hPlugin,'scanimage.interfaces.PmtController')
            %                      obj.hPmtControllers{end+1} = hPlugin;
            %                  end
            %              end
             
             if ~isempty(obj.hModel.hBScope2)
                 if obj.hModel.hBScope2.ecuInitSuccessful
                     obj.hPmtControllers{end+1} = obj.hModel.hBScope2;
                 end
             end
             
             hPmtController = [];
             for i = 1:numel(obj.hPmtControllers)
                 hPmtController = obj.hPmtControllers{i};
                 hPmtController.pmtsStatusUpdatedFcn = @obj.statusUpdatedFcn;
                 obj.numInstances = obj.numInstances + hPmtController.numPmts;
             end
             
             obj.abort();  % starts the timer to update the GUI
        end
        
        function delete(obj)
            
            for i = 1:numel(obj.hPmtControllers)
                if isobject(obj.hPmtControllers{i})
                    if isvalid(obj.hPmtControllers{i})
                        obj.hPmtControllers{i}.pmtsStatusUpdatedFcn = [];
                    end
                end
            end
            
            if ~isempty(obj.hTimer) && isvalid(obj.hTimer)
                stop(obj.hTimer);
                delete(obj.hTimer);
            end
        end
        
        
        function start(obj)
            stop(obj.hTimer);
        end
        
        
        function abort(obj)
            if ~strcmp(obj.hTimer.running, 'on')
                start(obj.hTimer);
            else
                %Dont really need a warning. Not really a problem if this happens
                %warning('Pmts abort called, but idle status update timer was already running. Start may never have been called.');
            end
        end
    end
    
    methods
        function updateStatus(obj,varargin)
            for i = 1:numel(obj.hPmtControllers)
               obj.hPmtControllers{i}.pmtsUpdateStatus();
            end            
        end
    end
        
    methods (Hidden)
        function statusUpdatedFcn(obj)
            % execute property setter methods to update GUI
            % only update GUI if data actually changed 
            
            obj.hModel.bscope2PmtValsSet = true;
            obj.Mod2ContSet = true;
            
            if any(obj.hModel.bscope2PmtPowersOn ~= obj.powersOn)
                obj.hModel.bscope2PmtPowersOn = obj.powersOn;
            end
            
            if any(obj.hModel.bscope2PmtGains ~= obj.gains)
                obj.hModel.bscope2PmtGains    = obj.gains;
            end
            
            if any(obj.hModel.bscope2PmtTripped ~= obj.tripped)
                obj.hModel.bscope2PmtTripped  = obj.tripped;
            end
            
            obj.Mod2ContSet = false;
        end
    end
    
    %% Property Getter/Setter
    methods
        function val = get.names(obj)
            if isempty(obj.hPmtControllers)
                val = [];
            else
                % Todo: Support multiple pmt controllers
                val = obj.hPmtControllers{1}.pmtNames;
            end
        end
        
        function set.powersOn(obj,val)
            
            %Validation
            validateattributes(val,{'logical'},{'vector'});            
            assert(numel(val) == obj.numInstances);
            
            %Side-effects
            obj.hPmtControllers{1}.pmtsPowerOn = val;
            
        end
        
        function val = get.powersOn(obj)
            if isempty(obj.hPmtControllers)
                val = [];
            else
                % Todo: Support multiple pmt controllers
                val = logical(obj.hPmtControllers{1}.pmtsPowerOn);
            end
        end
        
        function set.gains(obj,val)
            
            %Validation
            validateattributes(val,{'numeric'},{'vector','finite'});
            assert(numel(val) == obj.numInstances);
            
            %Side-effect
            obj.hPmtControllers{1}.pmtsGain = val;
            
        end
        
        function val = get.gains(obj)
            if isempty(obj.hPmtControllers)
                val = [];
            else
                val = obj.hPmtControllers{1}.pmtsGain;
            end
        end
        
        function val = get.tripped(obj)
            if isempty(obj.hPmtControllers)
                val = [];
            else
                val = obj.hPmtControllers{1}.pmtsTripped;
            end
        end
    end
end

% function s = zlclInitPropAttributes()
% s = struct();
% 
% s.powerOn = struct('Classes','binaryflex','Attributes',{{'vector'}});
% s.gains   = struct('Classes','numeric','Attributes',{{'vector','finite'}});
% s.tripped = struct('Classes','binaryflex','Attributes',{{'vector'}});
% end

%--------------------------------------------------------------------------%
% Pmts.m                                                                   %
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
