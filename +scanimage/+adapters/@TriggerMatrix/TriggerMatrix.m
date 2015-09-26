classdef TriggerMatrix < handle  
    properties
        % Specifiy external trigger inputs and outputs of the PXI system
        % Empty string ('')       specifies that the signal is unused/not connected
        % Value 'PFI0..15'        specifies that the signal is connected to the primariy IO DAQ device
        % Value '/PXIxSlotx/PFIx' specifies that the signal is connected to the daq device with the name 'PXIxSlotx'. This device must be installed in the same PXI chassis as the main DAQ device
        % Value '/FPGA/DIOx.x'    specifies that the signal is connected to the AUX connector of the FlexRIO Digitizer Module (requires a NI SCB-19 breakout box)
        
        periodClockIn = '';             % one of {'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        frameClockOut = '';             % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', /FPGA/DIO1.0..3'}
        beamModifiedLineClockOut = '';  % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO1.0..3'}
        acqTriggerIn = '';              % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        nextFileMarkerIn = '';          % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        acqInterruptTriggerIn = '';     % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        
        acqTriggerOut = '';             % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO1.0..3'}
        periodClockOut = '';            % one of {'', '/FPGA/DIO1.0..3'}
    end
    
    properties (Dependent)
        periodClockOnFallingEdge;         % default: false
        acqTriggerOnFallingEdge;          % default: false
        nextFileMarkerOnFallingEdge;      % default: false
        acqInterruptTriggerOnFallingEdge; % default: false
    end
    
    properties (SetAccess = immutable, Hidden)
        hModel;
        hAcq;
        
        hPrimaryIODevice;
        hDaqSystem;
        
        primaryIODeviceName;
        primaryIoDevPxiSlot;
        primaryIoDevPxiChassisNum;
        
        primaryPxiChassisNum;
        primaryPxiChassisDeviceNames;
    end 
    
    properties (SetAccess = private, Hidden)
        simulated = false;
    end
    
    properties (Constant,Hidden)
        % PXI_TRIGGER_MAP: Assignment of trigger signals on PXI backplane
        PXI_TRIGGER_MAP = containers.Map({'periodClock' , 'frameClock' , 'beamModifiedLineClock', 'acqTrigger' , 'nextFileMarker' , 'acqInterruptTrigger' , 'acqTriggerOut'},...
                                         {'PXI_Trig0'   , 'PXI_Trig1'  , 'PXI_Trig2'            , 'PXI_Trig3'  , 'PXI_Trig4'      , 'PXI_Trig5'           , 'PXI_Trig6'});
        debugOutput = false;
    end
    
    %% Lifecycle
    methods
        function obj = TriggerMatrix(hModel,primaryPxiChassisNum,primaryIODeviceName,simulated)
            % Validate input arguments
            validateattributes(hModel,{'scanimage.SI5'},{'scalar','nonempty'});
            obj.hAcq = hModel.hAcq;
            
            if nargin < 2 || isempty(primaryPxiChassisNum)
                primaryPxiChassisNum = 1;
            end
            
            if nargin < 3 || isempty(primaryIODeviceName)
                primaryIODeviceName = '';
            end
            
            if nargin < 4 || isempty(simulated)
                simulated = false;
            end
            
            validateattributes(primaryPxiChassisNum,{'numeric'},{'scalar','nonempty'});
            validateattributes(primaryIODeviceName,{'char'},{});
            validateattributes(simulated,{'logical'},{'scalar','nonempty'});
            
            obj.simulated = simulated;

            % get information about primary daq device
            import dabs.ni.daqmx.*
            obj.hDaqSystem = dabs.ni.daqmx.System();
            
            obj.primaryIODeviceName = primaryIODeviceName;
            obj.primaryPxiChassisNum = primaryPxiChassisNum;
            obj.primaryPxiChassisDeviceNames = obj.listDaqDevicesInPxiChassis(obj.primaryPxiChassisNum);
            
            if ~isempty(obj.primaryIODeviceName)
                obj.hPrimaryIODevice = dabs.ni.daqmx.Device(obj.primaryIODeviceName);

                daqDevBusType = get(obj.hPrimaryIODevice,'busType');
                if ~obj.simulated
                    assert(any(strcmp(daqDevBusType,{'DAQmx_Val_PXI','DAQmx_Val_PXIe'})),...
                        'The primary IO DAQ board must be installed in the same PXI chassis as the FlexRIO FPGA module');
                end

                obj.primaryIoDevPxiSlot = get(obj.hPrimaryIODevice,'PXISlotNum');
                obj.primaryIoDevPxiChassisNum = get(obj.hPrimaryIODevice,'PXIChassisNum');
                assert(obj.primaryIoDevPxiChassisNum == obj.primaryPxiChassisNum, 'The primary IO DAQ board must be installed in the same PXI chassis as the FlexRIO FPGA module');
            else
                obj.dispDbgMsg('No primary daq device specified. Absolute trigger names must be used (e.g. ''/PXI1Slot3/PF1'')');
            end
           
            
            % Configure FPGA to export/import trigger lines to PXI backplane
            obj.dispDbgMsg('Setting up PXI Trigger lines');
            obj.hAcq.periodClockIn = obj.PXI_TRIGGER_MAP('periodClock');
            obj.hAcq.frameClockOut = obj.PXI_TRIGGER_MAP('frameClock');
            obj.hAcq.acqTriggerIn = obj.PXI_TRIGGER_MAP('acqTrigger');
            obj.hAcq.nextFileMarkerIn = obj.PXI_TRIGGER_MAP('nextFileMarker');
            obj.hAcq.acqInterruptTriggerIn = obj.PXI_TRIGGER_MAP('acqInterruptTrigger');
            obj.hAcq.beamModifiedLineClockOut = obj.PXI_TRIGGER_MAP('beamModifiedLineClock');
            obj.hAcq.acqTriggerOut = obj.PXI_TRIGGER_MAP('acqTriggerOut');
        end
        
        function delete(obj)
            %Disconnect all routes
            obj.periodClockIn = '';
            obj.frameClockOut = '';
            obj.acqTriggerIn = '';
            obj.nextFileMarkerIn = '';
            obj.acqInterruptTriggerIn = '';
            obj.beamModifiedLineClockOut = '';
            obj.acqTriggerOut = '';
        end
    end

    
    methods
        function connectTerminals(obj,srcTerm,destTerms,connect)
            % srcTerm:   a string specifiying the source e.g. 'PFI0'
            % destTerms: a cell array specifiying the route endpoints e.g.: {'PFI1',PFI2'}
            % connect:   (Optional) if empty or true, the route is
            %               connected, otherwise it is disconnected            
            if nargin < 4 || isempty(connect)
                connect = true;
            end
            
            if isempty(srcTerm) || isempty(destTerms)
               return; 
            end
            
            validateattributes(destTerms,{'cell'},{});

            qualSrcTerm = obj.qualifyTermName(srcTerm);
            
            terminals = {destTerms{:},qualSrcTerm};
            for i = 1:length(terminals)
               terminal = terminals{i};
               assert(obj.areTerminalsInMainPxiChassis(terminal),...
                   'Connecting route failed: Terminal %s is not available in main PXI chassis',terminal);
            end
            
            for i = 1:length(destTerms)
                destTerm = destTerms{i};
                if isempty(destTerm)
                    continue;
                end
                
                qualDestTerm = obj.qualifyTermName(destTerm);
                if ~obj.simulated
                    if connect
                        obj.hDaqSystem.connectTerms(qualSrcTerm,qualDestTerm);
                        obj.dispDbgMsg('DAQmx connect Route %s to %s',qualSrcTerm,qualDestTerm);
                    else
                        obj.hDaqSystem.disconnectTerms(qualSrcTerm,qualDestTerm);
                        obj.dispDbgMsg('DAQmx disconnect Route %s to %s',qualSrcTerm,qualDestTerm);
                    end
                end
            end
        end
        
        function qualifiedTermName = qualifyTermName(obj,termName)
            validateattributes(termName,{'char'},{'vector'});
            
            if isempty(termName)
                qualifiedTermName = '';
            elseif isempty(strfind(termName,'/'))
                qualifiedTermName = sprintf('/%s/%s',obj.hPrimaryIODevice.deviceName,termName); % e.g. '/PXI1Slot3/PFI1'
            else
                qualifiedTermName = termName;
            end
        end
        
        function tf = areTerminalsInMainPxiChassis(obj,terminals)
            if ischar(terminals)
                terminals = cellstr(terminals);
            end
            
            tf = true;
            for i = 1:length(terminals)
                terminal = terminals{i};
                if isempty(terminal)
                    continue
                end
                deviceName = obj.getTerminalDeviceName(terminal);
                tf = tf && obj.isDeviceInMainPxiChassis(deviceName);                
            end
        end

        function deviceName = getTerminalDeviceName(obj,terminal)
                terminal = obj.qualifyTermName(terminal);
                slashes = strfind(terminal,'/');
                deviceName = terminal(slashes(1)+1:slashes(2)-1);
        end
        
        function tf = isDeviceInMainPxiChassis(obj,deviceName)
           tf = any(ismember(obj.primaryPxiChassisDeviceNames,deviceName));
        end
        
        function pxiDaqDeviceNames = listDaqDevicesInPxiChassis(obj,pxiChassisNum)
            import dabs.ni.daqmx.*
            devNames = get(obj.hDaqSystem,'devNames');
            
            if isempty(devNames)
                devNames = {};
            else
                devNames = most.idioms.strsplit(devNames,','); % native strsplit is not available pre Matlab 2013
            end
            
            pxiDaqDeviceNames = {};
            
            for i = 1:length(devNames)
                devName = devNames{i};
                hDaqDevice = dabs.ni.daqmx.Device(devName);
                daqDevBusType = get(hDaqDevice,'busType');
                if(any(strcmp(daqDevBusType,{'DAQmx_Val_PXI','DAQmx_Val_PXIe'})))
                    devPxiChassisNum = get(hDaqDevice,'PXIChassisNum');
                    if devPxiChassisNum == pxiChassisNum
                        pxiDaqDeviceNames = {pxiDaqDeviceNames{:},devName};
                    end
                end
            end
        end
    end
    
    methods (Hidden) 
        function [deviceName,terminal] = getDeviceAndTerminal(obj,fullTerm)
           if isempty(fullTerm)
               deviceName = '';
               terminal = '';
           else
               slashes = strfind(fullTerm,'/');
               if isempty(slashes)
                  deviceName = obj.primaryIODeviceName;
                  terminal = fullTerm;
               elseif length(slashes) == 2
                  deviceName = fullTerm(slashes(1)+1:slashes(2)-1);
                  terminal = fullTerm(slashes(2)+1:end);
               else
                  error('Invalid format of trigger terminal ''%s''. Valid Formats are ''/DevName/PFIx'' or ''PFIx''',fullTerm); 
               end
           end 
        end
        
        function fullTerm = getFullTerminal(obj,deviceName,terminal)
           if isempty(deviceName)
               fullTerm = deviceName;
           else
               fullTerm = sprintf('/%s/%s',deviceName,terminal);
           end
        end
    end
    
    %% Property Setter Methods
    methods
        function set.periodClockIn(obj,newTerminal)
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('periodClock');
            
            % first disconnect the existing route
            oldTerminal = obj.periodClockIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            oldPxiTriggerLineDaq = obj.getFullTerminal(oldDevice,pxiTriggerLine);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hAcq.periodClockIn = pxiTriggerLine;
                case 'FPGA'
                    obj.hAcq.periodClockIn = pxiTriggerLine;
                otherwise
                    obj.connectTerminals(oldTerminal,{oldPxiTriggerLineDaq},false);
            end
            obj.periodClockIn = '';
            
            % try connecting the new Route
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            newPxiTriggerLineDaq = obj.getFullTerminal(newDevice,pxiTriggerLine);
            switch newDevice
                case ''
                    % No Route to set
                    assert(isempty(newTerminalOnly),'No device found for terminal %s. Possible reason: no primaryIODeviceName defined in system',newTerminalOnly);
                    obj.hAcq.periodClockIn = pxiTriggerLine;
                case 'FPGA'
                    obj.hAcq.periodClockIn = newTerminalOnly;
                otherwise
                    assert(obj.isDeviceInMainPxiChassis(newDevice));
                    obj.connectTerminals(newTerminal,{newPxiTriggerLineDaq},true);
                    obj.hAcq.periodClockIn = pxiTriggerLine;
            end
            
            %set property value
            obj.periodClockIn = newTerminal;
        end
        
        function set.frameClockOut(obj,newTerminal)
           % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('frameClock');
            
            % first disconnect the existing route
            oldTerminal = obj.frameClockOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            oldPxiTriggerLineDaq = obj.getFullTerminal(oldDevice,pxiTriggerLine);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                case 'FPGA'
                    obj.hAcq.hFpga.FrameClockTerminalOut2 = '';
                otherwise
                    obj.connectTerminals(oldPxiTriggerLineDaq,{oldTerminal},false);
            end
            obj.frameClockOut = '';
            
            % try connecting the new Route
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            newPxiTriggerLineDaq = obj.getFullTerminal(newDevice,pxiTriggerLine);
            switch newDevice
                case ''
                    % No Route to set
                    assert(isempty(newTerminalOnly),'No device found for terminal %s. Possible reason: no primaryIODeviceName defined in system',newTerminalOnly);
                case 'FPGA'
                    obj.hAcq.hFpga.FrameClockTerminalOut2 = newTerminalOnly;
                otherwise
                    assert(obj.isDeviceInMainPxiChassis(newDevice));
                    obj.connectTerminals(newPxiTriggerLineDaq,{newTerminal},true);
            end
            
            %set property value
            obj.frameClockOut = newTerminal;
        end
        
        function set.acqTriggerIn(obj,newTerminal)
           % get pxi trigger line assignment
           pxiTriggerLine = obj.PXI_TRIGGER_MAP('acqTrigger');
            
            % first disconnect the existing route
            oldTerminal = obj.acqTriggerIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            oldPxiTriggerLineDaq = obj.getFullTerminal(oldDevice,pxiTriggerLine);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hAcq.acqTriggerIn = pxiTriggerLine;
                case 'FPGA'
                    obj.hAcq.acqTriggerIn = pxiTriggerLine;
                otherwise
                    obj.connectTerminals(oldTerminal,{oldPxiTriggerLineDaq},false);
            end
            obj.acqTriggerIn = '';
            
            % try connecting the new Route
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            newPxiTriggerLineDaq = obj.getFullTerminal(newDevice,pxiTriggerLine);
            switch newDevice
                case ''
                    % No Route to set
                    obj.hAcq.acqTriggerIn = pxiTriggerLine;
                    assert(isempty(newTerminalOnly),'No device found for terminal %s. Possible reason: no primaryIODeviceName defined in system',newTerminalOnly);
                case 'FPGA'
                    obj.hAcq.acqTriggerIn = newTerminalOnly;
                otherwise
                    assert(obj.isDeviceInMainPxiChassis(newDevice));
                    obj.connectTerminals(newTerminal,{newPxiTriggerLineDaq},true);
                    obj.hAcq.acqTriggerIn = pxiTriggerLine;
            end
            
            %set property value
            obj.acqTriggerIn = newTerminal;           
        end
        
        function set.nextFileMarkerIn(obj,newTerminal)
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('nextFileMarker');
            
            % first disconnect the existing route
            oldTerminal = obj.nextFileMarkerIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            oldPxiTriggerLineDaq = obj.getFullTerminal(oldDevice,pxiTriggerLine);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hAcq.nextFileMarkerIn = pxiTriggerLine;
                case 'FPGA'
                    obj.hAcq.nextFileMarkerIn = pxiTriggerLine;
                otherwise
                    obj.connectTerminals(oldTerminal,{oldPxiTriggerLineDaq},false);
            end
            obj.nextFileMarkerIn = '';
            
            % try connecting the new Route
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            newPxiTriggerLineDaq = obj.getFullTerminal(newDevice,pxiTriggerLine);
            switch newDevice
                case ''
                    % No Route to set
                    obj.hAcq.nextFileMarkerIn = pxiTriggerLine;
                    assert(isempty(newTerminalOnly),'No device found for terminal %s. Possible reason: no primaryIODeviceName defined in system',newTerminalOnly);
                case 'FPGA'
                    obj.hAcq.nextFileMarkerIn = newTerminalOnly;
                otherwise
                    assert(obj.isDeviceInMainPxiChassis(newDevice));
                    obj.connectTerminals(newTerminal,{newPxiTriggerLineDaq},true);
                    obj.hAcq.nextFileMarkerIn = pxiTriggerLine;
            end
            
            %set property value
            obj.nextFileMarkerIn = newTerminal;
        end
        
        function set.acqInterruptTriggerIn(obj,newTerminal)
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('acqInterruptTrigger');
            
            % first disconnect the existing route
            oldTerminal = obj.acqInterruptTriggerIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            oldPxiTriggerLineDaq = obj.getFullTerminal(oldDevice,pxiTriggerLine);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hAcq.acqInterruptTriggerIn = pxiTriggerLine;
                case 'FPGA'
                    obj.hAcq.acqInterruptTriggerIn = pxiTriggerLine;
                otherwise
                    obj.connectTerminals(oldTerminal,{oldPxiTriggerLineDaq},false);
            end
            obj.acqInterruptTriggerIn = '';
            
            % try connecting the new Route
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            newPxiTriggerLineDaq = obj.getFullTerminal(newDevice,pxiTriggerLine);
            switch newDevice
                case ''
                    % No Route to set
                    obj.hAcq.acqInterruptTriggerIn = pxiTriggerLine;
                    assert(isempty(newTerminalOnly),'No device found for terminal %s. Possible reason: no primaryIODeviceName defined in system',newTerminalOnly);
                case 'FPGA'
                    obj.hAcq.acqInterruptTriggerIn = newTerminalOnly;
                otherwise
                    assert(obj.isDeviceInMainPxiChassis(newDevice));
                    obj.connectTerminals(newTerminal,{newPxiTriggerLineDaq},true);
                    obj.hAcq.acqInterruptTriggerIn = pxiTriggerLine;
            end
            
            %set property value
            obj.acqInterruptTriggerIn = newTerminal;
        end
        
        function set.beamModifiedLineClockOut(obj,newTerminal)
           % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('beamModifiedLineClock');
            
            % first disconnect the existing route
            oldTerminal = obj.beamModifiedLineClockOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            oldPxiTriggerLineDaq = obj.getFullTerminal(oldDevice,pxiTriggerLine);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                case 'FPGA'
                    obj.hAcq.hFpga.BeamClockTerminalOut2 = '';
                otherwise
                    obj.connectTerminals(oldPxiTriggerLineDaq,{oldTerminal},false);
            end
            obj.beamModifiedLineClockOut = '';
            
            % try connecting the new Route
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            newPxiTriggerLineDaq = obj.getFullTerminal(newDevice,pxiTriggerLine);
            switch newDevice
                case ''
                    % No Route to set
                    assert(isempty(newTerminalOnly),'No device found for terminal %s. Possible reason: no primaryIODeviceName defined in system',newTerminalOnly);
                case 'FPGA'
                    obj.hAcq.hFpga.BeamClockTerminalOut2 = newTerminalOnly;
                otherwise
                    assert(obj.isDeviceInMainPxiChassis(newDevice));
                    obj.connectTerminals(newPxiTriggerLineDaq,{newTerminal},true);
            end
            
            %set property value
            obj.beamModifiedLineClockOut = newTerminal;
        end
        
        function set.acqTriggerOut(obj,newTerminal)
           % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('acqTriggerOut');
            
            % first disconnect the existing route
            oldTerminal = obj.acqTriggerOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            oldPxiTriggerLineDaq = obj.getFullTerminal(oldDevice,pxiTriggerLine);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                case 'FPGA'
                    obj.hAcq.hFpga.AcqTriggerTerminalOut2 = '';
                otherwise
                    obj.connectTerminals(oldPxiTriggerLineDaq,{oldTerminal},false);
            end
            obj.acqTriggerOut = '';
            
            % try connecting the new Route
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            newPxiTriggerLineDaq = obj.getFullTerminal(newDevice,pxiTriggerLine);
            switch newDevice
                case ''
                    % No Route to set
                    assert(isempty(newTerminalOnly),'No device found for terminal %s. Possible reason: no primaryIODeviceName defined in system',newTerminalOnly);
                case 'FPGA'
                    obj.hAcq.hFpga.AcqTriggerTerminalOut2 = newTerminalOnly;
                otherwise
                    assert(obj.isDeviceInMainPxiChassis(newDevice));
                    obj.connectTerminals(newPxiTriggerLineDaq,{newTerminal},true);
            end
            
            %set property value
            obj.acqTriggerOut = newTerminal;
        end
        
        function set.periodClockOut(obj,newTerminal)
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            assert(strcmp(newDevice,'FPGA'),'The period clock can only be mirrored on the FPGA connector block');
            obj.hAcq.hFpga.PeriodClockTerminalOut = newTerminalOnly;
            obj.periodClockOut = newTerminal;
        end
    end
    
    %% Dependent Properties Access methods
    methods
        function set.periodClockOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.hAcq.periodClockOnFallingEdge = val;
        end
        
        function val = get.periodClockOnFallingEdge(obj)
            val = obj.hAcq.periodClockOnFallingEdge;
        end

        function set.acqTriggerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.hAcq.acqTriggerOnFallingEdge = val;
        end
        
        function val = get.acqTriggerOnFallingEdge(obj)
            val = obj.hAcq.acqTriggerOnFallingEdge;
        end
        
        function set.nextFileMarkerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.hAcq.nextFileMarkerOnFallingEdge = val;
        end
        
        function val = get.nextFileMarkerOnFallingEdge(obj)
            val = obj.hAcq.nextFileMarkerOnFallingEdge;
        end
        
        function set.acqInterruptTriggerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.hAcq.acqInterruptTriggerOnFallingEdge = val;
        end
        
        function val = get.acqInterruptTriggerOnFallingEdge(obj)
            val = obj.hAcq.acqInterruptTriggerOnFallingEdge;
        end
    end
    
    %% Private Methods for Debugging
    methods (Access = private)
        function dispDbgMsg(obj,varargin)
            if obj.debugOutput
                fprintf(horzcat('Class: ',class(obj),': ',varargin{1},'\n'),varargin{2:end});
            end
        end
    end
end

%--------------------------------------------------------------------------%
% TriggerMatrix.m                                                          %
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
