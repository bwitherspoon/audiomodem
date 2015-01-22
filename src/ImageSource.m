% Copyright (c) 2015, C. Brett Witherspoon <cbwithersp42@students.tntech.edu>
% 
% Permission to use, copy, modify, and/or distribute this software for any
% purpose with or without fee is hereby granted, provided that the above
% copyright notice and this permission notice appear in all copies.
% 
% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

classdef ImageSource < matlab.System & matlab.system.mixin.FiniteSource
    % A class for generating packets from an image file.
    %
    % The output is a column vector of bytes.
    %
    % See README.md for details.

    properties (Nontunable)
        Verbose = false
        BytesPerFrame = 216;
        ShowImage = false;
        Filename = ''
    end

    properties (Access=private)
        Offset
        Data
    end

    properties (Constant)
        HeaderCount = 2
        HeaderWordSize = 16
    end

    methods
        function obj = ImageSource(varargin)
            setProperties(obj,nargin,varargin{:});
            if isempty(obj.Filename)
                [filename, pathname] = uigetfile('*.*', 'Select Image to Transfer');
                if ~filename
                    error('No image file selected for transfer');
                end
                obj.Filename = strcat(pathname, filename);
            end
        end
    end

    methods (Access=protected)
        function setupImpl(obj)
            % Load image
            img = imread(obj.Filename);
            if obj.ShowImage
                imshow(img);
            end
            fprintf('Transmitting %d bytes...\n', numel(img));
            % Create header
            header = Serdes.WordsToBitStream(size(img)', obj.HeaderWordSize);
            header = repmat(header, obj.HeaderCount, 1);
            % Serialize the image data
            serializer = Serdes(size(img));
            data = serializer.Serialize(img);
            % Add CRC-32 checksum
            crc = comm.CRCGenerator(...
                'Polynomial', [32 26 23 22 16 12 11 10 8 7 5 4 2 1 0]);
            data = crc.step(data);
            % Assemble packet
            packet = [header; data];
            rem = mod(length(packet), 8*obj.BytesPerFrame);
            if rem
                padding = randi([0,1], 8*obj.BytesPerFrame - rem, 1);
                packet = [packet ; padding];
            end
            obj.Data = Serdes.BitStreamToBytes(packet);
            obj.Offset = 0;
        end

        function resetImpl(obj)
            obj.Offset = 0;
        end

        function data = stepImpl(obj)
            if ~isDone(obj)
                data = obj.Data(obj.Offset+1:obj.Offset+obj.BytesPerFrame);
                obj.Offset = obj.Offset + obj.BytesPerFrame;
            else
                data = [];
            end
        end

        function done = isDoneImpl(obj)
            done = obj.Offset == length(obj.Data);
        end

        function N = getNumInputsImpl(obj)
            N = 0;
        end
    end
end
