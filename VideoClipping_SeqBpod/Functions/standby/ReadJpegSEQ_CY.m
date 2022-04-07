function [ImageCellArray, headerInfo] = ReadJpegSEQ(fileName,frames)
% -------------------------------------------------------------------------
% Read compressed or uncompressed monochrome NorPix image sequence in MATLAB.
% Reading window for compressed sequences requires a separate .idx file
% named as the source file (eg. test.seq.idx).
% 
% INPUTS
%    fileName:       String containing the full path to the sequence
%    frame:          1x1 double of the frame index
% OUTPUTS
%    I:              the image (matrix)
% 
% 2021.04.30 by Yue Huang
% Last modified by Yu Chen

fid = fopen(fileName,'r','b'); % open the sequence
fidIdx = fopen([fileName '.idx']);
endianType = 'ieee-le'; % use little endian machine format ordering for reading bytes

headerInfo = readHeader(fid,endianType);


% set read window & determine number of frames to read
if frames(1) <= 0, first = 1; else, first = frames(1); end
if frames(2) <= 0, last = headerInfo.AllocatedFrames; else, last = frames(2); end
readAmount = last+1 - first;

ImageCellArray = cell(readAmount,2);
for i=1:readAmount
    frame = first-1+i;
    
    % read frame using idx buffer size information
    if frame == 1
        readStart = 1028;
        fseek(fidIdx,8,'bof');
        imageBufferSize = fread(fidIdx,1,'ulong',endianType);
    else
        readStartIdx = frame*24;
        fseek(fidIdx,readStartIdx,'bof');
        readStart = fread(fidIdx,1,'uint64',endianType)+4;
        imageBufferSize = fread(fidIdx,1,'ulong',endianType);
    end
    fseek(fid,readStart,'bof');
    JpegSEQ = fread(fid,imageBufferSize,'uint8',endianType);
    
%     ImageCellArray{i,1} = nparray2mat(py.cv2.imdecode(py.numpy.uint8(py.numpy.array(JpegSEQ)),uint8(0)));
    ImageCellArray{i,1} = uint8(py.cv2.imdecode(py.numpy.uint8(py.numpy.array(JpegSEQ)),uint8(0)));
    
    % read timestamp
    readStart = readStart+imageBufferSize-4;
    fseek(fid,readStart,'bof');
    ImageCellArray{i,2} = readTimestamp(fid, endianType);
end

fclose(fidIdx);
fclose(fid);
end

function headerInfo = readHeader(fid,endianType)
    % get imageInfo
    fseek(fid,548,'bof');  % jump to position 548 from beginning
    imageInfo = fread(fid,24,'uint32',0,endianType); % read 24 bytes with uint32 precision
    headerInfo.ImageWidth = imageInfo(1);
    headerInfo.ImageHeight = imageInfo(2);
    headerInfo.ImageBitDepth = imageInfo(3);
    headerInfo.ImageBitDepthReal = imageInfo(4);
    headerInfo.ImageSizeBytes = imageInfo(5);
    vals = [0,100,101,200:100:600,610,620,700,800,900];
    fmts = {'Unknown','Monochrome','Raw Bayer','BGR','Planar','RGB',...
        'BGRx', 'YUV422', 'YUV422_20', 'YUV422_PPACKED', 'UVY422', 'UVY411', 'UVY444'};
    headerInfo.ImageFormat = fmts{vals == imageInfo(6)};
    fseek(fid,572,'bof');
    headerInfo.AllocatedFrames = fread(fid,1,'ushort',endianType);
    fseek(fid,620,'bof');
    headerInfo.Compression = fread(fid,1,'uint8',endianType);
    % Additional sequence information
    fseek(fid,28, 'bof');
    headerInfo.HeaderVersion = fread(fid,1,'long',endianType);
    fseek(fid,32,'bof');
    headerInfo.HeaderSize = fread(fid,4/4,'long',endianType);
    fseek(fid,592, 'bof');
    DescriptionFormat = fread(fid,1,'long',endianType)';
    fseek(fid,36,'bof');
    headerInfo.Description = fread(fid,512,'ushort',endianType)';
    if DescriptionFormat == 0 %#ok Unicode
        headerInfo.Description = native2unicode(headerInfo.Description);
    elseif DescriptionFormat == 1 %#ok ASCII
        headerInfo.Description = char(headerInfo.Description);
    end
    fseek(fid,580,'bof');
    headerInfo.TrueImageSize = fread(fid,1,'ulong',endianType);
    fseek(fid,584,'bof');
    headerInfo.FrameRate = fread(fid,1,'double',endianType);
end

function result = nparray2mat(nparray)
	%nparray2mat Convert an nparray from numpy to a Matlab array
	%   Convert an n-dimensional nparray into an equivalent Matlab array
	data_size = cellfun(@int64,cell(nparray.shape));
	if length(data_size)==1
        % This is a simple operation
        result=double(py.array.array('d', py.numpy.nditer(nparray)));
	elseif length(data_size)==2
        % order='F' is used to get data in column-major order (as in Fortran
        % 'F' and Matlab)
        result=reshape(double(py.array.array('d', ...
            py.numpy.nditer(nparray, pyargs('order', 'F')))), ...
            data_size);
    else
        % For multidimensional arrays more manipulation is required
        % First recover in python order (C contiguous order)
        result=double(py.array.array('d', ...
            py.numpy.nditer(nparray, pyargs('order', 'C'))));
        % Switch the order of the dimensions (as Python views this in the
        % opposite order to Matlab) and reshape to the corresponding C-like
        % array
        result=reshape(result,fliplr(data_size));
        % Now transpose rows and columns of the 2D sub-arrays to arrive at the
        % correct Matlab structuring
        result=permute(result,[length(data_size):-1:1]);
    end
end

function time = readTimestamp(fid, endianType)
    imageTimestamp = fread(fid,1,'int32',endianType);
    subSec = fread(fid,2,'uint16',endianType);
    subSec_str = cell(2,1);
    for sS = 1:2
        subSec_str{sS} = num2str(subSec(sS));
        while length(subSec_str{sS})<3
            subSec_str{sS} = ['0' subSec_str{sS}];
        end
    end
    timestampDateNum = imageTimestamp/86400 + datenum(1970,1,1);
    time = [datestr(timestampDateNum) ':' subSec_str{1},subSec_str{2}];
    return
end