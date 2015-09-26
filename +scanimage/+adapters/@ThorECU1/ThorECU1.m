classdef ThorECU1 < most.MachineDataFile
%% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)    
properties (Constant, Hidden)
    %Value-Required properties
    mdfClassName = mfilename('class');
    mdfHeading = 'Thor ECU1';

    %Value-Optional properties
    mdfDependsOnClasses; %#ok<MCCPI>
    mdfDirectProp;       %#ok<MCCPI>
    mdfPropPrefix;       %#ok<MCCPI>
end
    
properties (Constant)
    spiDoChans = {'port0/line0','port0/line1','port0/line2','port0/line3'};
    spiDataRate = 1000; % data rate in Hz
end

properties (Hidden)
    devName;
    hSpiDoTask;
    
    hSI;
    hListenerZoom;
    
    hSerial;
end

properties (SetAccess = private)
    scannerActive = true; %assume scanner is active at start, so it can be actively set to off in constructor
end

methods
    function obj = ThorECU1(hSI)
        obj.hSI = hSI;
        
        try
            %Configure serial connection
            validateattributes(obj.mdfData.comPort,{'numeric'},{'scalar','integer','positive','finite','nonempty'});
            obj.hSerial = serial(sprintf('COM%d',obj.mdfData.comPort));
            obj.hSerial.BaudRate = 112500;
            obj.hSerial.Terminator = 'CR';
            obj.hSerial.DataBits = 8;
            obj.hSerial.FlowControl = 'software';

            fopen(obj.hSerial);

            thorECUID = obj.writeSerialCmd('id?');
            assert(~isempty(strfind(thorECUID,'THORLABS PCU2A')),...
                'ThorECU: Could not find ECU at COM Port %d. Device response: \n %s \n',obj.mdfData.comPort,thorECUID);
            fprintf('ThorECU: Thorlabs ECU reports ID: \n%s\n',thorECUID);
            obj.activateScanner(false);

            %Configure DAQ channels
            assert(obj.hSI.hScan.mdfData.galvoAOChanID == 1,...
                'ThorECU: Wrong AO Channel for galvo control configured. Set galvoAOChanID = 1 in Machine Data File and restart Matlab/ScanImage');

            fprintf('ThorECU: Configuring ResScan2D for ThorECU compatibility\n');
            obj.devName = obj.hSI.hScan.mdfData.scanCtrlDeviceName;

            %import dabs.ni.daqmx.*;
            obj.hSpiDoTask = scanimage.util.priv.safeCreateTask('transfer digital pattern'); %HACK
            for i = 1:numel(obj.spiDoChans)
                obj.hSpiDoTask.createDOChan(obj.devName,obj.spiDoChans{i},[],'DAQmx_Val_ChanPerLine');
            end
            obj.hSpiDoTask.cfgSampClkTiming(obj.spiDataRate, 'DAQmx_Val_FiniteSamps', 10); %sampsPerChanToAcquire is reconfigured for every write operation

            %setting periodClockIn to PFI0 on hScan Galvo DAQ board
            periodClockIn = sprintf('/%s/%s',obj.devName,'PFI0'); % e.g. '/PXI1Slot3/PFI0'
            fprintf('ThorECU: Routing periodClockIn to %s\n',periodClockIn);
            obj.hSI.hTriggerMatrix.periodClockIn = periodClockIn;

            %set phase potentiometer of ThorECU to 0
            obj.resetPhase();

            %switch zoom output from hScan to ThorECU plugin
            obj.hListenerZoom = addlistener(obj.hSI.hScan,'resonantScannerOutputVoltsUpdated',@obj.resonantScannerOutputVoltsUpdated);
            obj.hSI.hScan.resonantScannerZoomOutput = false;

        catch ME
            fprintf(2,'ThorECU: Error during initialization of Plugin.\nEnsure the ECU is powered on, the USB cable is connected and the right serial port is configured in the Machine Data File.\nDisabling ThorECU Plugin\n Error stack: \n  %s \n',ME.getReport());
            most.idioms.reportError(ME);
            obj.delete();
        end
    end
    
    function delete(obj)
        if ~isempty(obj.hListenerZoom) && isvalid(obj.hListenerZoom)
            delete(obj.hListenerZoom);
        end
        
        if ~isempty(obj.hSpiDoTask) && isvalid(obj.hSpiDoTask)
            obj.setZoomVolts(0);
            obj.hSpiDoTask.stop();
            delete(obj.hSpiDoTask);
            clear obj.hSpiDoTask;
        end
        
        if ~isempty(obj.hSerial) && isvalid(obj.hSerial)
            try
                obj.activateScanner(false);
                fclose(obj.hSerial);
            catch
                fprintf('ThorECU: Resetting ECU failed\n');
            end
            delete(obj.hSerial);
        end
    end
    
    function resonantScannerOutputVoltsUpdated(obj,src,~)
        zoomVolts = src.resonantScannerLastWrittenValue;
        obj.setZoomVolts(zoomVolts);
    end
    
    function setZoomData(obj,data)
        if data == 0
            obj.activateScanner(false);
        else
            obj.activateScanner(true);
        end
        
        bitStream = obj.bitStream(data);
        obj.writeSpiData(bitStream);
    end
    
    function resetPhase(obj)
        bitStream = uint8([9 1 1 3 1 3 1 3 1 3 1 3 1 3 1 3 1 3 1 3 1 3 1 3 9 9 9 9 9 9 9 9 9 9 9 9 9 9]');
        obj.writeSpiData(bitStream);
    end
    
    function setZoomVolts(obj,volts)
        data = volts / 5 * 255;
        obj.setZoomData(data);
    end
end

methods (Hidden)
    function activateScanner(obj,activate)
        if nargin < 2 || isempty(activate)
            activate = true;
        end
        
        if obj.scannerActive ~= activate
            if activate
                obj.writeSerialCmd('scan=1');
            else
                obj.writeSerialCmd('scan=0');
            end
            obj.scannerActive = activate;
        end
    end
    
    function answer = writeSerialCmd(obj, cmd)
        if obj.hSerial.BytesAvailable  % flush buffer
            fread(obj.hSerial,obj.hSerial.BytesAvailable);
        end
        
        fprintf(obj.hSerial,cmd);
        if nargout
            pause(0.5); % serial communication is pretty slow
            answer = char(fread(obj.hSerial,obj.hSerial.BytesAvailable)');
            cmdEsc = regexptranslate('escape',cmd);
            answer = regexprep(answer,sprintf('^%s\r',cmdEsc),''); % remove mirrored command
            answer = regexprep(answer,'\r> *$','');                % remove command prompt
        end
    end
    
    function writeSpiData(obj, data)
        obj.hSpiDoTask.set('sampQuantSampPerChan',length(data));
        obj.hSpiDoTask.set('bufOutputBufSize',length(data));
        data = obj.portU8ToLines(data,numel(obj.spiDoChans));
        obj.hSpiDoTask.writeDigitalData(data,1,false);
        obj.hSpiDoTask.start();
        obj.hSpiDoTask.waitUntilTaskDone(1);
        obj.hSpiDoTask.stop();
        obj.hSpiDoTask.control('DAQmx_Val_Task_Unreserve'); 
    end
        
    function bitstreamU8 = bitStream(obj, data)
        enableU8 = 17; %0b00010001
        dataU8 = cast(data,'uint8');

        dataU16 = typecast(uint8([dataU8, enableU8]),'uint16'); %0b00010001data

        dataout = zeros(1,16*2,'uint8');

        for i = 0:15
            %format
            bit3 = bitshift(uint16(1),3);
            bit2 = bitget(dataU16,16-i); %transfer highest significant bit first
            bit2 = bitshift(bit2,2);
            bit1 = 0;
            bit1 = bitshift(bit1,1);
            bit0 = 0;

            out = bitor(bit0,bit1);
            out = bitor(out,bit2);
            out = bitor(out,bit3);

            bit1 = 1;
            bit1 = bitshift(bit1,1);
            outclockhigh = bitor(out,bit1);

            dataout(i*2 + 1) = out;
            dataout(i*2 + 2) = outclockhigh;
        end

        prefix1 = 9; %0b1001
        prefix2 = 8; %0b1000

        suffix1 = 9; %0b1001
        suffix2 = 9; %0b1001

        bitstreamU8 = [prefix1, prefix2, dataout, suffix1, suffix2];
    end
    
    function lineData = portU8ToLines(obj,data,numLines)
        numSamples = length(data);
        lineData = false(numSamples,numLines);
        for sampleNum = 1:length(data)
            for lineNum = 1:numLines
                val = bitget(data(sampleNum),lineNum);
                lineData(sampleNum,lineNum) = logical(val);
            end
        end
    end
end
end

%--------------------------------------------------------------------------%
% ThorECU1.m                                                               %
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
