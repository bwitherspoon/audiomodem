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

classdef FrameGenerator < matlab.System
    % A class for creating PHY layer frames.
    %
    % The input should be a column vector of bytes or bits.
    %
    % The output as a column vector of symbols.
    %
    % See README.md for details.

    properties (Nontunable)
        BitInput = false
        ModulationOrder = 4
        PreambleUniqueWord = ([+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1] + 1) / 2; % Barker 13
        PreambleCount = 2
        ScramblerPolynomial = [1 0 0 0 1 0 0 1]
        ScramblerInitialConditions = [0 0 0 0 0 0]
        EncoderEnabled = true
        EncoderTrellisStructure = poly2trellis(7, [171 133])
        EncoderPuncturePattern = [1; 1; 0; 1; 0; 1]
    end

    properties (Access=private)
        Preamble
        Scrambler
        Encoder
        Interleaver
        Modulator
    end

    methods
        function obj = FrameGenerator(varargin)
            setProperties(obj,nargin,varargin{:});
            obj.Scrambler = comm.Scrambler(...
                'CalculationBase', 2, ...
                'Polynomial', obj.ScramblerPolynomial, ...
                'InitialConditions', obj.ScramblerInitialConditions');
            obj.Encoder = comm.ConvolutionalEncoder(...
                'TrellisStructure', obj.EncoderTrellisStructure, ...
                'TerminationMethod', 'Truncated', ...
                'PuncturePatternSource', 'Property', ...
                'PuncturePattern', obj.EncoderPuncturePattern);
            obj.Modulator = comm.RectangularQAMModulator(...
                'ModulationOrder', obj.ModulationOrder, ...
                'BitInput', true, ...
                'NormalizationMethod', 'Average power', ...
                'AveragePower', 1);
            mod = comm.BPSKModulator('PhaseOffset', pi/4);
            preamble = repmat(obj.PreambleUniqueWord', obj.PreambleCount, 1);
            obj.Preamble = step(mod, preamble);
        end
    end

    methods (Access=protected)
        function setupImpl(obj, payload)
            rate = (length(obj.EncoderPuncturePattern)/2) / sum(obj.EncoderPuncturePattern);
            % Compute the number of coded bits per frame
            if obj.BitInput
                ncbpf = (length(payload) + 8) / rate;
            else
                ncbpf = 8*(length(payload)+1) / rate;
            end
            obj.Interleaver = comm.MatrixInterleaver(...
                'NumRows', ncbpf/8, ...
                'NumColumns', 8);
        end
        function resetImpl(obj)
            reset(obj.Scrambler);
            reset(obj.Encoder);
            reset(obj.Interleaver);
            reset(obj.Modulator);
        end

        function releaseImpl(obj)
            release(obj.Scrambler);
            release(obj.Encoder);
            release(obj.Interleaver);
            release(obj.Modulator);
        end

        function frame = stepImpl(obj, payload)
            if ~obj.BitInput
                stream = Serdes.BytesToBitStream(payload);
            end

            % Scramble data
            % Generate a random seed and header for the scrambler
            seed = randi([0 1], 1, length(obj.ScramblerPolynomial)-1);
            header = zeros(8*ceil(length(seed)/8), 1);
            if obj.Scrambler.isLocked()
                obj.Scrambler.release();
            end
            obj.Scrambler.InitialConditions = seed;
            stream = obj.Scrambler.step([header ; stream]);

            % Encode data
            if obj.EncoderEnabled
                stream = obj.Encoder.step(stream);
            end

            % Interleave data
            stream = obj.Interleaver.step(stream);

            % Modulate data
            symbols = obj.Modulator.step(stream);

            % Concat preamble and packet
            frame = [obj.Preamble; symbols];
        end

    end
end
