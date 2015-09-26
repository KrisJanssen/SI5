function scanimage5()
%SCANIMAGE5 Starts ScanImage application and its GUI(s)
% ScanImage 5 is free, open-source software for resonant-scanned two-photon laser scanning microscopy optimized for brain science applications
% SI5 supports flexible (custom to commercial) microscope hardware and relies on National Instruments FPGA-based digitizer and data processing hardware
% SI5 hardware is able to capture and react to precise timestamps of external experimental signals, e.g. physiology or behavior signals or events
%
% Support email: support@vidriotech.com
% Support ticket website: support.vidriotech.com (login required)
% For further documentation visit: http://scanimage.org/
%
% Copyright Vidrio Technologies, LLC 2014
% See LICENSE.txt for license terms

if evalin('base','~exist(''hSI'')')
    try
        hSI = scanimage.SI5();
        hSICtl = scanimage.SI5Controller(hSI); %#ok<NASGU>
    
        assignin('base','hSI',hSI);
        assignin('base','hSICtl',hSI.hController{1});

        hSI.initialize();
    catch ME
        if exist('hSI', 'var')
            if isobject(hSI)
                if isvalid(hSI)
                    delete(hSI);
                end
            end
        end
        
        evalin('base','clear hSI hSICtl MDF');
        ME.rethrow;
    end
else
    most.idioms.warn('ScanImage 5 is already running.');
    evalin('base','hSICtl.raiseAllGUIs')
end

end

%--------------------------------------------------------------------------%
% scanimage5.m                                                             %
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
