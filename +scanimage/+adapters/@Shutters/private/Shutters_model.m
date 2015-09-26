%% Shutters
%Shutter(s) used to prevent any beam exposure from reaching specimen during idle periods
shutterOpenLevel = true;            % Logical: Indicates TTL level (false=LO;true=HI) corresponding to shutter open state for each shutter line. If scalar, value applies to all shutterLineIDs
shutterOpenTime = 0;                % Numeric [sec]: Time to delay following certain shutter open commands (e.g. between stack slices), allowing shutter to fully open before proceeding.