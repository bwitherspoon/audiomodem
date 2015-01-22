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

classdef Serdes
    % A class for matrix and tensor serialization and deserialization.
    %
    % See README.md for details.

    properties (Access=private)
        Shape
    end

    methods
        function obj = Serdes(shape)
            obj.Shape = shape;
        end

        function ser = Serialize(obj, des)
            ser = reshape(des, [], 1);
            ser = obj.BytesToBitStream(ser);
        end

        function des = Deserialize(obj, ser)
            des = obj.BitStreamToBytes(ser);
            des = reshape(des, obj.Shape);
        end
    end

    methods (Static)
        function stream = WordsToBitStream(words, wordsize)
            stream = de2bi(words, wordsize, 'left-msb')';
            stream = reshape(stream, [], 1);
        end

        function words = BitStreamToWords(stream, wordsize)
            words = reshape(logical(stream) , wordsize, [])';
            words = bi2de(words, 'left-msb');
        end

        function stream = BytesToBitStream(bytes)
            stream = de2bi(uint8(bytes), 8, 'left-msb')';
            stream = logical(reshape(stream, [], 1));
        end

        function bytes = BitStreamToBytes(stream)
            bytes = reshape(uint8(stream), 8, [])';
            bytes = bi2de(bytes, 'left-msb');
        end
    end
end
