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

classdef FrameSynchronizer < matlab.System
    % A class for receiving PHY layer frames.
    %
    % The input should be a column vector of symbols.
    %
    % The output is a column vector of bytes or bits.
    %
    % See README.md for details.

    properties (Nontunable)
        Verbose = false
        BitOutput = false
        ModulationOrder = 4
        PreambleUniqueWord = ([+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1] + 1) / 2
        PreambleCount = 2;
        PreambleThreshold = 1
        DescramblerPolynomial = [1 0 0 0 1 0 0 1]
        DescramblerInitialConditions = [0 0 0 0 0 0]
        DecoderEnabled = true
        DecoderTrellisStructure = poly2trellis(7, [171 133])
        DecoderPuncturePattern = [1; 1; 0; 1; 0; 1]
        DecoderTracebackDepth = 96;
    end

    properties (Access=private)
        SymbolsPerFrame
        Offset
        Phase
        Buffer
        PreambleBits
        Preamble
        PreambleDemodulator
        Demodulator
        Correlator
        Deinterleaver
        Decoder
        Descrambler
    end

    properties (Constant)
        HeaderLength = 8
    end

    methods
        function obj = FrameSynchronizer(varargin)
            setProperties(obj,nargin,varargin{:});
            obj.Offset = 0;
            obj.PreambleBits = repmat(obj.PreambleUniqueWord', obj.PreambleCount, 1);
            obj.PreambleDemodulator = comm.BPSKDemodulator('PhaseOffset', pi/4);
            mod = comm.BPSKModulator('PhaseOffset', pi/4);
            obj.Preamble = step(mod, obj.PreambleBits);
            obj.Demodulator = comm.RectangularQAMDemodulator(...
                'ModulationOrder', obj.ModulationOrder, ...
                'BitOutput', true, ...
                'NormalizationMethod', 'Average power', ...
                'AveragePower', 1);
            obj.Correlator = dsp.Crosscorrelator;
            obj.Descrambler = comm.Descrambler(...
                'CalculationBase', 2, ...
                'Polynomial', obj.DescramblerPolynomial, ...
                'InitialConditions', obj.DescramblerInitialConditions);
            obj.Decoder = comm.ViterbiDecoder(...
                'TrellisStructure', obj.DecoderTrellisStructure, ...
                'InputFormat', 'Hard', ...
                'InvalidQuantizedInputAction', 'Error', ...
                'TracebackDepth', obj.DecoderTracebackDepth, ...
                'TerminationMethod', 'Truncated', ...
                'PuncturePatternSource', 'Property', ...
                'PuncturePattern', obj.DecoderPuncturePattern);
        end
    end

    methods (Access=protected)
        function setupImpl(obj, symbols)
            obj.SymbolsPerFrame = length(symbols);
            ncbpf = (length(symbols)-length(obj.Preamble))*log2(obj.ModulationOrder);
            obj.Deinterleaver = comm.MatrixDeinterleaver(...
                'NumRows', ncbpf/8, ...
                'NumColumns', 8);
            obj.Buffer = dsp.Buffer(...
                2*obj.SymbolsPerFrame, ...
                obj.SymbolsPerFrame, ...
                complex(0.001, 0.001));
        end

        function resetImpl(obj)
            obj.Offset = 0;
            reset(obj.Buffer);
            reset(obj.PreambleDemodulator);
            reset(obj.Demodulator);
            reset(obj.Correlator);
            reset(obj.Descrambler);
            reset(obj.Decoder);
            reset(obj.Deinterleaver);
        end

        function releaseImpl(obj)
            release(obj.Buffer);
            release(obj.PreambleDemodulator);
            release(obj.Demodulator);
            release(obj.Correlator);
            release(obj.Descrambler);
            release(obj.Decoder);
            release(obj.Deinterleaver);
        end

        function [payload_symbols, payload] = stepImpl(obj, symbols)
            % Buffer at least one frame
            buffered = step(obj.Buffer, symbols);

            % Get frame at estimated timing offset
            frame = buffered(obj.Offset+1:obj.Offset+obj.SymbolsPerFrame);

            % Estimate phase offset from preamble
            theta = mean(conj(obj.Preamble).*frame(1:length(obj.Preamble)));
            phase = angle(theta);

            % Phase offset correction
            frame = frame .* exp(-1j*phase);

            payload_symbols = frame(length(obj.Preamble)+1:end);

            % Validate frame with preamble hamming distance
            preamble = obj.PreambleDemodulator.step(frame(1:length(obj.Preamble)));
            distance = sum(preamble ~= obj.PreambleBits);
            if (distance > obj.PreambleThreshold)
                payload = [];
            else
                % Demodulate data
                data = obj.Demodulator.step(payload_symbols);

                % Deinterleave data
                data = obj.Deinterleaver.step(data);

                % Decode data
                if obj.DecoderEnabled
                    data = obj.Decoder.step(data);
                end

                % Descramble data
                % Estimate initial state from scrambler header
                head = data(1:length(obj.DescramblerPolynomial)-1);
                state = zeros(size(head));
                % FIXME hardcoded for default polynomial
                state(1:3) = flipud(xor(head(1:3), head(5:7)));
                state(4) = xor(head(4), state(1));
                state(5:7) = xor(flipud(head(1:3)), state(2:4));
                % Set the initial state and descramble
                if obj.Descrambler.isLocked()
                    obj.Descrambler.release()
                end
                obj.Descrambler.InitialConditions = state;
                data = obj.Descrambler.step(data);
                % Extract payload without scrambler header
                n = 8*ceil(length(obj.DescramblerPolynomial-1)/8);
                payload = data(n+1:end);

                if ~obj.BitOutput
                    payload = Serdes.BitStreamToBytes(payload);
                end
            end

            % Estimate the timing offset for the next frame
            correlation = abs(step(obj.Correlator, obj.Preamble, symbols));
            [~, argmax] = max(correlation);
            obj.Offset = mod(length(symbols)-argmax, length(symbols)-1);
        end

        function N = getNumOutputsImpl(obj)
            N = 2;
        end
    end
end
