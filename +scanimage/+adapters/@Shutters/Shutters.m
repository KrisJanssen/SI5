classdef Shutters < most.MachineDataFile
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Shutters';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %% PUBLIC PROPERTIES
    properties (SetObservable)
        shutterDelay = 0; %Numeric scalar or array indicating time(s), in milliseconds, to delay opening of shutter(s) from start of acquistion. Value of 0 means to open before acquisition starts.
    end
    
    %% INTERNAL PROPS
    properties (Hidden,SetAccess=protected)
        hShuttersTask; %Array of shutter DO Tasks
        hModel;
    end
    
    %% LIFECYCLE
    methods
        function obj = Shutters(hModel,digitalIODeviceName,digitalIODeviceIsFPGA)
            if nargin < 1 || isempty(hModel)
                hModel = [];
            end
            
            if nargin < 2 || isempty(digitalIODeviceName)
                digitalIODeviceName = '';
            end
            
            if nargin < 3 || isempty(digitalIODeviceIsFPGA)
                digitalIODeviceIsFPGA = false;
            end
            
            obj.hModel = hModel;
            
            %Todo: make these object properties
            % port 2, line 4 translates to PFI12 on X Series boards
            obj.mdfData.shutterDeviceNames = digitalIODeviceName; %String or cell string array of device name(s) on which shutter output(s) are generated. If single string, applies to all shutterLineIDs
            obj.mdfData.shutterPortIDs = 2; %Scalar integer or array of integers indicating port number for each shutter line. If scalar, same port number used for all shutterLineIDs
            obj.mdfData.shutterLineIDs = 4; %Scalar integer or array of integers indicating line number for each shutter line. One value for each shutter line controlled by application
            obj.mdfData.shutterIDs = {}; %Optional string cell array of identifiers for the shutters, one for each of the shutterLineIDs            
            
            if digitalIODeviceIsFPGA
                obj.hShuttersTask = [];
                assert(~isempty(obj.hModel) && isvalid(obj.hModel),'For FPGA Shutter outpt hModel needs to be valid');
                obj.hModel.hAcq.shutterOut = 'DIO1.3';
            else
                obj.ziniPrepareShutters();
            end
        end
        
        function delete(obj)
            for i = 1:length(obj.hShuttersTask)
                obj.hShuttersTask(i).stop();
                delete(obj.hShuttersTask(i));
                clear obj.hShuttersTask(i);
            end
            
        end
    end
    
    %% HIDDEN INITIALIZATION METHODS
    methods (Hidden)
        %******************************************************************
        %SHUTTERS
        %******************************************************************
        function ziniDisableShutterFeature(obj)
            if ~isempty(obj.hShuttersTask)
                delete(obj.hShuttersTask);
            end
            obj.hShuttersTask = dabs.ni.daqmx.Task.empty();
        end
        
        function ziniPrepareShutters(obj)
            import dabs.ni.daqmx.*
            
            try
                tfShutterFeatureOn = ~isempty(obj.mdfData.shutterDeviceNames) && ...
                    ~isempty(obj.mdfData.shutterPortIDs) && ...
                    ~isempty(obj.mdfData.shutterLineIDs);
                if ~tfShutterFeatureOn
                    obj.ziniDisableShutterFeature();
                    fprintf(1,'Disabling shutter feature...\n');
                    return;
                end
                
                % shutterLineIDs
                obj.zprvMDFVerify('shutterLineIDs',{{'numeric'},{'integer' 'vector' 'nonnegative'}},[]);
                numShutters = length(obj.mdfData.shutterLineIDs);
                
                % shutterDeviceNames
                if ischar(obj.mdfData.shutterDeviceNames)
                    obj.mdfData.shutterDeviceNames = cellstr(obj.mdfData.shutterDeviceNames);
                end
                obj.zprvMDFScalarExpand('shutterDeviceNames',numShutters);
                obj.zprvMDFVerify('shutterDeviceNames',{},@(x)iscellstr(x)&&numel(x)==numShutters&&all(cellfun(@(y)~isempty(y),x)));
                
                % shutterPortIDs
                obj.zprvMDFScalarExpand('shutterPortIDs',numShutters);
                obj.zprvMDFVerify('shutterPortIDs',{{'numeric'},{'integer' 'vector' 'nonnegative'}},@(x)numel(x)==numShutters);
                
                % shutterOpenLevel
                obj.zprvMDFScalarExpand('shutterOpenLevel',numShutters);
                obj.zprvMDFVerify('shutterOpenLevel',{{'numeric' 'logical'},{'binary' 'vector'}},@(x)numel(x)==numShutters);
                
                % shutterBeforeEOM (MOVED TO BEAMS CLASS)
                %obj.zprvMDFVerify('shutterBeforeEOM',{{'numeric' 'logical'},{'binary' 'scalar'}},[]);
                
                % shutterIDs
                if isempty(obj.mdfData.shutterIDs)
                    obj.mdfData.shutterIDs = arrayfun(@num2str,(1:numShutters)','UniformOutput',false);
                end
                obj.zprvMDFVerify('shutterIDs',{},@(x)iscellstr(x)&&numel(x)==numShutters);
                
                %Create shutter Tasks
                obj.hShuttersTask = Task.empty();
                for i=1:numShutters
                    idString = obj.mdfData.shutterIDs{i};
                    hShutter = scanimage.util.priv.safeCreateTask(sprintf('Shutter %s',idString)); %HACK: should not need safe create
                    hShutter.createDOChan(obj.mdfData.shutterDeviceNames{i},sprintf('port%d/line%d',obj.mdfData.shutterPortIDs(i),obj.mdfData.shutterLineIDs(i)));
                    hShutter.writeDigitalData(double(~obj.mdfData.shutterOpenLevel(i))); %Close shutter
                    obj.hShuttersTask(end+1) = hShutter;
                end
                
            catch ME
                obj.ziniDisableShutterFeature();
                fprintf(2,'Error occurred during shutter initialization. Incorrect MachineDataFile settings likely cause. \n Disabling shutter feature. \n Error stack: \n');
                most.idioms.reportError(ME);
                %throwAsCaller(obj.DException('','InitShuttersErr',' Error stack: \n   %s',ME.getReport()));
            end
        end
    end
    
    %% PUBLIC ACCESS METHODS
    methods
        function set.shutterDelay(obj,val)
            obj.zprvAssertIdle('shutterDelay');
            val = obj.validatePropArg('shutterDelay',val);
            
            %For now - force property value to 0. The shutterDelay feature is not supported as of SI 4.1
            if val > 0
                fprintf(2,'WARNING: Shutter delay values > 0 not supported at this time. Forcing value to 0.\n');
                val = 0;
            end
            
            obj.shutterDelay = val;
        end
        
        function shuttersTransition(obj,openTF,applyShutterDelay)
            for i=1:length(obj.hShuttersTask)
                if openTF
                    writeDigitalData(obj.hShuttersTask(i),obj.mdfData.shutterOpenLevel(i));
                else
                    writeDigitalData(obj.hShuttersTask(i),~obj.mdfData.shutterOpenLevel(i));
                end
            end
            
            % naive implementation of a shutter on the FPGA. currently only one shutter output terminal is available on the FPGA
            if ~isempty(obj.hModel) && isvalid(obj.hModel)
                output = xor(~obj.mdfData.shutterOpenLevel(1),openTF);
                obj.hModel.hAcq.shutterOutput = output;
            end
            
            if nargin < 3
                applyShutterDelay = false;
            end
%            fprintf('applyShutterDelay: %d ',applyShutterDelay);
%            fprintf('isfield(obj.mdfData,''shutterOpenTime''): %d ', isfield(obj.mdfData,'shutterOpenTime'));
%            fprintf('obj.mdfData.shutterOpenTime: %d ',obj.mdfData.shutterOpenTime);
          
            if openTF && applyShutterDelay && isfield(obj.mdfData,'shutterOpenTime') && obj.mdfData.shutterOpenTime > 0
                most.idioms.pauseTight(obj.mdfData.shutterOpenTime);
            end
        end
    end
    
    %% HIDDEN METHODS (Misc)
    methods (Hidden)
        function zprvMDFScalarExpand(obj,mdfVarName,N)
            if isscalar(obj.mdfData.(mdfVarName))
                obj.mdfData.(mdfVarName) = repmat(obj.mdfData.(mdfVarName),N,1);
            end
        end
        
        function zprvMDFVerify(obj,mdfVarName,validAttribArgs,assertFcn)
            val = obj.mdfData.(mdfVarName);
            try
                if ~isempty(validAttribArgs)
                    validateattributes(val,validAttribArgs{:});
                end
                if ~isempty(assertFcn)
                    assert(assertFcn(val));
                end
            catch ME
                error('SI5:MDFVerify','Invalid value for MachineDataFile variable ''%s''.',mdfVarName);
            end
        end
    end    
end

%--------------------------------------------------------------------------%
% Shutters.m                                                               %
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
