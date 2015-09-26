classdef ThorBScope2 < most.MachineDataFile & dabs.thorlabs.BScope2 & scanimage.interfaces.PmtController
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Thor BScope2';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    
    %% Abstract property realization (scaniamge.interfaces.PmtController)
    properties (SetAccess = protected)
        numPmts = 4;                                       % [numerical] number of PMTs managed by the PMT controller
        pmtNames = {'Thor 1','Thor 2','Thor 3','Thor 4'};  % Cell array of strings with a short name for each PMT
    end
    
    properties (Hidden)
        pmtsStatusUpdatedFcn;    % [function_handle] called after the PMT controller status changed
        pmtsStatusLastUpdated;   % time of last pmt status update
    end
    
    properties (Dependent)
        acqStatusUpdateInterval; % rate at which to update the pmt status during an acquisition
    end
    
    properties (Dependent, Hidden)
        pmtsPowerOn;        % [logical]   array containing power status for each PMT
        pmtsGain;           % [numerical] array containing gain setting for each PMT
        pmtsTripped;        % [logical]   array containing trip status for each PMT    
    end
    
    
    %% Class properties
    
    properties (SetAccess = immutable, Hidden)
       hSI;
       lscDontDelete = true; % This is to prevent StageController from deleting the object
    end
    
    properties (SetAccess = private, Hidden)
        hListenerZoom;
    end
    
    
    %% LIFECYCLE
    methods
        function obj = ThorBScope2(hModel)
            assert(~isempty(hModel), 'Failed to load ThorBScope2 adapter. hModel is empty');
            obj = obj@dabs.thorlabs.BScope2('suppressInitWarning', true);
            obj.hSI = hModel;
            
            validateattributes(obj.mdfData.ecu2ComPort,{'numeric'},{'scalar','integer','positive','finite','nonempty'});
            obj.initEcu2('comPort', obj.mdfData.ecu2ComPort);
            
            if obj.ecuInitSuccessful
                if isa(obj.hSI.hScan,'scanimage.adapters.ResScanCtrl')
                    obj.configureResScan2D();
                end
                addlistener(obj, 'pmtsStatus', 'PostSet', @obj.handleEvent);
                obj.pmtsUpdateStatus();
            end
            
            if ~isempty(obj.mdfData.mcm5000ComPort)
                validateattributes(obj.mdfData.mcm5000ComPort,{'numeric'},{'scalar','integer','positive','finite','nonempty'});
                obj.initLsc('comPort', obj.mdfData.mcm5000ComPort, 'hasRotation', obj.mdfData.hasRotation);

                if obj.lscInitSuccessful
                    addlistener(obj, 'flipperMirrorPosition', 'PostSet', @obj.handleEvent);
                    addlistener(obj, 'galvoResonantMirrorInPath', 'PostSet', @obj.handleEvent);
                    addlistener(obj, 'galvoGalvoMirrorInPath', 'PostSet', @obj.handleEvent);
                end
            else
                most.idioms.warn('ThorBScope2 adapter loaded but stage controller COM port not specified. BScope2 stage disabled.');
            end
        end
        
        function delete(obj)            
            if ~isempty(obj.hListenerZoom) && isvalid(obj.hListenerZoom)
                delete(obj.hListenerZoom);
            end
        end
        
    end
    
    
    %% ABSTRACT METHOD IMPLEMENTATIONS (scanimage.interfaces.PmtController)
    methods
        function pmtsUpdateStatus(obj,varargin)
            obj.pmtsStatusLastUpdated = tic;
            obj.updatePmtsStatus();
        end
    end
    
    
    %% PROPERTY ACCESS METHODS
    methods
        
        function set.pmtsPowerOn(obj,val)
            obj.setPmtsPower(val);
        end
        
        
        function val = get.pmtsPowerOn(obj)
            val = obj.pmtsStatus.on;
        end
        
        
        function set.pmtsGain(obj,val)
            obj.setPmtsGains(val)
        end
        
        
        function val = get.pmtsGain(obj)
            val = obj.pmtsStatus.gain;
        end
        
        
        function val = get.pmtsTripped(obj)
            val = obj.pmtsStatus.tripped;
        end
        
        
        function val = get.acqStatusUpdateInterval(obj)
            val = obj.mdfData.acqStatusUpdateInterval;
        end
        
        
        function set.acqStatusUpdateInterval(obj, val)
            validateattributes(val,{'numeric'},{'scalar','positive','finite','nonempty'});
            obj.mdfData.acqStatusUpdateInterval = val;
        end
        
    end
    
    
    %% HIDDEN METHODS
    methods (Hidden)        
                
        function resonantScannerOutputVoltsUpdated(obj,src,~)
            obj.zoomVolts = src.resonantScannerLastWrittenValue;
        end
        
    end
    
    
    %% PRIVATE METHODS
    methods (Access = private)
        
        function configureResScan2D(obj)
            %check AO pinout
            assert(obj.hSI.hScan.mdfData.galvoAOChanID == 1,...
                'ThorBScope2: Wrong AO Channel for galvo control configured. Set galvoAOChanID = 1 in Machine Data File and restart Matlab/ScanImage');
            
            fprintf('ThorBScope2: Configuring ResScan2D for ThorECU compatibility\n');
            devName = obj.hSI.hScan.mdfData.scanCtrlDeviceName;
            
            %setting periodClockIn to PFI0 on hScan Galvo DAQ board
            periodClockIn = sprintf('/%s/%s',devName,'PFI0'); % e.g. '/PXI1Slot3/PFI0'
            fprintf('ThorBScope2: Routing periodClockIn to %s\n',periodClockIn);
            obj.hSI.hTriggerMatrix.periodClockIn = periodClockIn;
            
            %switch zoom output from hScan to ThorECU plugin
            obj.hListenerZoom = addlistener(obj.hSI.hScan,'resonantScannerOutputVoltsUpdated',@obj.resonantScannerOutputVoltsUpdated);
            obj.hSI.hScan.resonantScannerZoomOutput = false;
        end
        
    end
    
    
    %% EVENT HANDLER
    methods (Static)
        function handleEvent(src, evnt)
            switch src.Name
                
                case 'pmtsStatus'
                    if ~isempty(evnt.AffectedObject.pmtsStatusUpdatedFcn)
                        evnt.AffectedObject.pmtsStatusUpdatedFcn();
                    end
                    
                case 'flipperMirrorPosition'
                    if ~strcmp(evnt.AffectedObject.hSI.bscope2FlipperMirrorPosition, evnt.AffectedObject.flipperMirrorPosition)
                        evnt.AffectedObject.hSI.bscope2FlipperMirrorPosition = evnt.AffectedObject.flipperMirrorPosition;
                    end
                    
                case 'galvoResonantMirrorInPath'
                    if evnt.AffectedObject.hSI.bscope2GalvoResonantMirrorInPath ~= evnt.AffectedObject.galvoResonantMirrorInPath
                        evnt.AffectedObject.hSI.bscope2GalvoResonantMirrorInPath = evnt.AffectedObject.galvoResonantMirrorInPath;
                    end
                    
                case 'galvoGalvoMirrorInPath'
                    if evnt.AffectedObject.hSI.bscope2GalvoGalvoMirrorInPath ~= evnt.AffectedObject.galvoGalvoMirrorInPath
                        evnt.AffectedObject.hSI.bscope2GalvoGalvoMirrorInPath = evnt.AffectedObject.galvoGalvoMirrorInPath;
                    end
            end
        end
    end
    
end

%--------------------------------------------------------------------------%
% ThorBScope2.m                                                            %
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
