function A = opentif(fname)
%OPENTIF Matlab open file function for reading ScanImage-generated TIF files
% A = opentif(fname)
% This is a passthrough of the scanimage.util.opentif() utility
% Using openxxx() naming convention allows use of MATLAB open() function with filename completion
%
% USAGE
%   opentif(varargin): extracts header & displays to command line
%   A = opentif(varargin): extracts image data into output matrix A
%
% NOTES
%   The scanimage.util.opentif() function provides additional features for
%   selective readout of specific frame/slice/channel/volume indices via
%   additional input argument flags that are not available by this MATLAB
%   open()

A = [];

if nargout
    [~,A] = scanimage.util.opentif(fname);
else 
    h = scanimage.util.opentif(fname);
    
    assignin('base','sitifheader',h);
    disp(h);
end



%--------------------------------------------------------------------------%
% opentif.m                                                                %
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
