function [header,Aout] = opentif(varargin)
%% function [header,Aout] = opentif(varargin)
% Opens a ScanImage TIF file, extracting its header information and, if specified, stores all of image contents as output array Aout if specified. 
% By default, Aout, if specified for output, is of size MxNxCxFxSxV, where C spans the channel indices, F spans the frame indicies, S spans the 
% slice indices, and V the volume indices.
%
% NOTE: IF the second output argument (Aout) is not assigned to output variable
%       THEN image file is not actually read -- only  header information is extracted
%       
%% SYNTAX
%   opentif()
%   opentif(filename)
%   header = opentif(...)
%   [header,Aout] = opentif(...)
%       filename: Name of TIF file, with or without '.tif' extension. If omitted, a dialog is launched to allow interactive selection.
%       flagN/flagNArg: Flags (string-valued) and/or flag/value pairs, in any order, specifying options to use in opening specified file
%
%       header: Structure comprising information stored by ScanImage into TIF header
%       Aout: MxNxCxFxSxV array, with images of size MxN for C channels, F frames, S slices, and V volumes. Default type is uint16. 
%
% NOTE: IF the second output argument (Aout) is not assigned to output variable
%       THEN image file is not actually read -- only header information is extracted
%
%% FLAGS (case-insensitive)
%
%   WITH ARGUMENTS
%       'channel' or 'channels': Argument specifies subset of channel(s) to extract. Ex: 1,[1 3], 2:4. 
%       'frame' or 'frames': Argument specifies subset of frames present to extract. Use 'inf' to specify all frames above highest specified value. Ex: 1:30, [50 inf], [1:9 11:19 21 inf]
%       'slice' or 'slices': Argument specifies subset of slices present to extract. Use 'inf' to specify all slices above highest specified value. Ex: 1:30, [50 inf], [1:9 11:19 21 inf]
%       'volume' or 'volumes': Argument specifies subset of volumes present to extract. Use 'inf' to specify all slices above highest specified value. Ex: 1:30, [50 inf], [1:9 11:19 21 inf]
%
%% NOTES
%   This function replaces the scim_openTif() function supplied with ScanImage 4.2
%   
%   TODO: Port more advanced features to ScanImage 5 from SI3/4 scim_openTif
%

%% Constants/Inits
error(nargoutchk(0,3,nargout,'struct'));

%% Parse input arguments

flagNames = {'channel' 'channels' 'slice' 'slices' 'frame' 'frames' 'volume' 'volumes'};
argFlags = {'channel' 'channels' 'slice' 'slices' 'frame' 'frames' 'volume' 'volumes'};

flagIndices = find(cellfun(@(x)ischar(x) && (ismember(lower(x),flagNames) || ismember(lower(x),argFlags)),varargin));

flags = cellfun(@lower,varargin(flagIndices),'UniformOutput',false);
if isempty(flags)
    flags = {};
end

%% Determine input file
if isempty(find(flagIndices==1)) && nargin>=1 && ischar(varargin{1})
    fileName = varargin{1};
else
    fileName = '';
end

if isempty(fileName)
    [f, p] = uigetfile({'*.tif;*.tiff'},'Select Image File');
    if f == 0
        return;
    end
    fileName = fullfile(p,f); 
end

%Extract filepath for future use
%[filePath,fileStem,fileExt] = fileparts((fileName));

%% Read TIFF file; extract # frames & image header
if ~exist(fileName,'file') && ~exist([fileName '.tif'],'file') && ~exist([fileName '.tiff'],'file') 
    error('''%s'' is not a recognized flag or filename. Aborting.',fileName);
elseif exist([fileName '.tif'],'file') 
    fileName = [fileName '.tif'];
elseif exist([fileName '.tiff'],'file') 
    fileName = [fileName '.tiff'];
end

%disp(['Loading file ' fileName]);

warning('off','MATLAB:tifflib:TIFFReadDirectory:libraryWarning');
hTif = Tiff(fileName);

headerLeadStr = {   'frameNumbers',...
                    'frameTimestamps',...
                    'acqTriggerTimestamps',...
                    'nextFileMarkerTimestamps',...
                    'dcOverVoltage'};

fileVersion = 5;
[header, numImages] = parseHeaderToStruct(hTif,fileVersion,headerLeadStr);        
hdr = extractHeaderData(header,fileVersion);

%% Read image meta-data
savedChans = hdr.savedChans;

%Display channel information to user
%disp(['Matrix of channels saved: ' mat2str(savedChans)]);

numChans = length(savedChans);
numPixels = hdr.numPixels;
numLines = hdr.numLines;
numSlices = hdr.numSlices;
numVolumes = hdr.numVolumes;
numFrames = hdr.numFrames;

if numSlices > 1 && numFrames > 1
    error('Cannot interpret multiple frames and slices simultaneously at this time.');
end

% This makes sure there are no issues with nextTrigger data
if numFrames > 1
    numFrames = floor(numImages/numChans/numSlices/numVolumes);
elseif numSlices > 1
    numSlices = floor(numImages/numChans/numVolumes);
end
% disp(['numImages  = ' num2str(numImages)])
% disp(['numChans   = ' num2str(numChans)])
% disp(['numFrames  = ' num2str(numFrames)])
% disp(['numSlices  = ' num2str(numSlices)])
% disp(['numVolumes = ' num2str(numVolumes)])


if ~numFrames || ~numSlices
    error('Acquisition did not complete a single frame or slice. Aborting.');
end

%Remove extra headers for multiple channels since they are identical
numhdrs = length(headerLeadStr);
% disp(['The number of top-header entries is ' num2str(numhdrs)]);  %Should be 5 in this case
numUniqueHeaders = numImages/numChans;  % This should account for ext trigger mode
if numChans > 1
    tempHeader = zeros(numhdrs, numUniqueHeaders); 
    
    for iter = 1:numhdrs    
        headSame = zeros(numChans, numUniqueHeaders); 

        for i = 1:numChans
            eval(['headSame(i, :) = header.' headerLeadStr{iter} '(1, i:numChans:length(header.' ...
                headerLeadStr{iter} '));']);
        end

        for i = 2:numChans
            if ~isequal(headSame(1, :), headSame(i,:))
                error('Unequal top header elements among channels. Aborting.');
            end
        end
        
        %Do this for each top header element to save processing
        eval(['tempHeader(iter,:)= header.' headerLeadStr{iter} '(1, 1:numChans:length(header.' ...
            headerLeadStr{iter} '));']);
        eval(['header.' headerLeadStr{iter} '= tempHeader(iter,:);']);
    end
end

%VI120910A: Detect/handle header-only operation (don't read data)
if nargout <=1
    return;
end

%% Process Flags

%Determine channels to extract
if any(ismember({'channel' 'channels'},flags))
    selectedChans = getArg({'channel' 'channels'});
    
    if ~isempty(setdiff(selectedChans,savedChans))
        selectedChans(find(setdiff(selectedChans,savedChans))) = [];
        warning('Some specified channels to extract not detected in file and, hence, ignored');
        if isempty(selectedChans)
            warning('No saved channels are specified to extract. Aborting.');
            return;
        end
    end
else
    selectedChans = savedChans;
end

%This mode stays given the nature of non-selected channel storage
%Auxiliary mapping for channel selection to index
chanKey = num2cell(savedChans);
chanVal = 1:length(savedChans);   %+++ Change to savedChans for selection if no resizing occurs?
chanMap = containers.Map(chanKey,chanVal);

%Determine slices to extract
if numSlices >= 1 && any(ismember({'slice' 'slices'},flags))
    selectedSlices = selectImages({'slice' 'slices'},numSlices);
else
    %Extract all slices
    selectedSlices = 1:numSlices;
end

% RRR Extract all frames for now
%Determine frames to extract
if numFrames >= 1 && any(ismember({'frame' 'frames'},flags))
    selectedFrames = selectImages({'frame' 'frames'},numFrames);
else
    %Extract all frames
    selectedFrames = 1:numFrames;
end


%Determine volumes to extract
if numVolumes >= 1 && any(ismember({'volume' 'volumes'},flags))
    selectedVolumes = selectImages({'volume' 'volumes'},numVolumes);
else
    %Extract all frames
    selectedVolumes = 1:numVolumes;
end

    function selection = selectImages(selectionFlags, numItems)
        if any(ismember(selectionFlags,flags))
            selection = getArg(selectionFlags);
            %Handle 'inf' specifier in slice array
            if find(isinf(selection))
                selection(isinf(selection)) = [];
                if max(selection) < numItems
                    selection = [selection (max(selection)+1):numItems];
                end
            end
            if max(selection) > numItems
                error('Frame, slice or volume values specified are not found in file');
            end
        else
            selection = 1:numItems;
        end
    end

%Determine if any selection is being made
forceSelection = any(ismember({'channel' 'channels' 'slice' 'slices' 'frame' 'frames' 'volume' 'volumes'},flags));

%% Preallocate image data
switch hTif.getTag('SampleFormat')
    case 1
        imageDataType = 'uint16';
    case 2
        imageDataType = 'int16';
    otherwise
        assert('Unrecognized or unsupported SampleFormat tag found');
end

%Look-up values for faster operation
lenSelectedFrames = length(selectedFrames);
lenSelectedChans = length(selectedChans);
lenSelectedSlices = length(selectedSlices);
lenSelectedVolumes = length(selectedVolumes);

lenTotalChans = length(savedChans);
lenTotalSlices = numSlices;
lenTotalFrames = numFrames;
% lenTotalVolumes = numVolumes;

% if force6D
Aout = zeros(numLines,numPixels,lenSelectedChans,lenSelectedFrames,lenSelectedSlices,lenSelectedVolumes,imageDataType);    
% else
%     Aout = zeros(numLines,numPixels,numImages,imageDataType);
% end

%% Read image data
selectedChans = selectedChans';
% The following doesn't seem to be the issue
% disp(['lenSelectedChans is: ' num2str(lenSelectedChans) ', it should be 1 in this case']);

%OK! So the issue is probably that we should NOT be using the length of the
%selectedXXX, but the actual length of the original file. Otherwise, we
%will get the mess of errors we are getting right now!
if forceSelection
    for p = 1:lenSelectedVolumes
        for j = 1:lenSelectedSlices
            for k = 1:lenSelectedFrames
                for i = 1:lenSelectedChans
                    %SELECTION MODE: (can allow parameter selection)
                    idx = chanMap(selectedChans(i));
                    %Get the tiff-index for the frames
                    idx = lenTotalChans*(selectedFrames(k) - 1) + idx;
                    %Get the tiff-index for the slices
                    idx = lenTotalFrames*lenTotalChans*(selectedSlices(j) - 1) + idx;
                    %Get the tiff-index for the volumes
                    idx = lenTotalSlices*lenTotalFrames*lenTotalChans*(selectedVolumes(p) - 1) + idx;
                    
                    %+++ Test the following expression.
                    if ismember(selectedChans(i), savedChans)
                        hTif.setDirectory(idx);
                        Aout(:,:,i,k,j,p) = hTif.read();
                    end
                end
            end
        end
    end
else
    idx = 0;
    for p = 1:lenSelectedVolumes
        for j = 1:lenSelectedSlices
            for k = 1:lenSelectedFrames
                for i = 1:lenSelectedChans
                    %NO-SELECTION MODE: (more efficient)
                    idx = idx + 1;

                    if ismember(selectedChans(i), savedChans)
                        hTif.setDirectory(idx);
                        Aout(:,:,i,k,j,p) = hTif.read();
                    end
                end
            end
        end
    end
end
    
%% GENERAL HELPERS

    function arg = getArg(flag)
        [tf,loc] = ismember(flag,flags); %Use this approach, instead of intersect, to allow detection of flag duplication
        if length(find(tf)) > 1
            error(['Flag ''' flag ''' appears more than once, which is not allowed']);
        else %Extract location of specified flag amongst flags
            loc(~loc) = [];
        end
        flagIndex = flagIndices(loc);
        if length(varargin) <= flagIndex
            arg = [];
            return;
        else
            arg = varargin{flagIndex+1};
            if ischar(arg) && ismember(lower(arg),flags) %Handle case where argument was omitted, and next argument is a flag
                arg = [];
            end
        end
    end

    function [s numImg] = parseHeaderToStruct(tifObj,fileVersion,headerLead)
        if fileVersion == 5
            s = struct();
    
            %Parse SI5 from the first frame
            numImg = 1;
            while ~tifObj.lastDirectory()
                numImg = numImg + 1;
                tifObj.nextDirectory();
            end
            tifObj.setDirectory(1);
            
%             try
                frameString= tifObj.getTag('ImageDescription');
%             catch 
%                 disp('The input tiff file may be corrupt or its header empty')
%             end
            
            rows = textscan(frameString,'%s','Delimiter','\n');            
            rows = rows{1};

            %If the first frame is empty return
            if isempty(rows)
                return;
            end
            
            for c = 1:5
                eval(['s.' headerLead{c} '=zeros(1,numImg);'])
            end
            
            for frame = 1:numImg
                frameString  = tifObj.getTag('ImageDescription');       
                rows = textscan(frameString,'%s','Delimiter','\n');            
                rows = rows{1};
                
                for c = 1:5
                    row = rows{c};

                    % replace top-level name with 'obj'
                    [~, rmn] = strtok(row,'=');
                    row = ['s.' headerLead{c} '(frame)'  rmn];
                    %Check for empty cases +++
                    eval([row ';']);
                end
                if frame ~= numImg
                    tifObj.nextDirectory();
                end
            end
            
            % Handle SI5 field            
            tifObj.setDirectory(1);
            frameString  = tifObj.getTag('ImageDescription');       
            rows = textscan(frameString,'%s','Delimiter','\n');            
            rows = rows{1};
            
            for c = 6:numel(rows)
                row = rows{c};
                
                % replace top-level name with 'obj'
                [~, rmn] = strtok(row,'.');
                row = ['s' rmn];

                % deal with nonscalar nested structs/objs
                pat = '([\w]+)__([0123456789]+)\.';
                replc = '$1($2).';
                row = regexprep(row,pat,replc);

                % handle unencodeable value or nonscalar struct/obj
                unencodeval = '<unencodeable value>';
                if strfind(row,unencodeval)
                    row = strrep(row,unencodeval,'[]');
                end
                nonscalarstructobjstr = '<nonscalar struct/object>';
                if strfind(row,nonscalarstructobjstr)
                    row = strrep(row,nonscalarstructobjstr,'[]');
                end

                % handle ND array format produced by array2Str
                try 
                    if ~isempty(strfind(row,'&'))
                        equalsIdx = strfind(row,'=');
                        [dimArr rmn] = strtok(row(equalsIdx+1:end),'&');
                        arr = strtok(rmn,'&');
                        arr = reshape(str2num(arr),str2num(dimArr)); %#ok<NASGU,ST2NM>
                        eval([row(1:equalsIdx+1) 'arr;']);
                    else
                        eval([row ';']);
                    end
                catch ME %Warn if assignments to no-longer-extant properties are found
                    if strcmpi(ME.identifier,'MATLAB:noPublicFieldForClass')
                        equalsIdx = strfind(row,'=');
                        fprintf(1,'WARNING: Property ''%s'' was specified, but does not exist for class ''%s''\n', deblank(row(3:equalsIdx-1)),class(s));
                    else
                        ME.rethrow();
                    end
                end
            end
        end
    end

    function s = extractHeaderData(header,fileVersion)
        
        if fileVersion == 5
            if isfield(header,'SI5')
                localHdr = header.SI5;
            else
                assert(false);
            end
            
            s.savedChans = localHdr.channelsSave;
            s.numPixels = localHdr.pixelsPerLine;
            s.numLines = localHdr.linesPerFrame;
            s.numVolumes = localHdr.fastZNumVolumes;
            
            if isfield(localHdr,'acqNumAveragedFrames')
                saveAverageFactor = localHdr.acqNumAveragedFrames;
            else
                assert(false);
            end

            s.numFrames = localHdr.acqNumFrames / saveAverageFactor;
            
            s.numSlices = localHdr.stackNumSlices;
            
        else
            assert(false);
        end

    end


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
