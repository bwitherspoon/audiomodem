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

classdef Transmitter < matlab.System
    % A QAM transmit path PHY layer.
    %
    % The input should be a column vector of bytes.
    %
    % The output is a column vector of complex baseband samples.
    %
    % See README.md for details.

    properties (Nontunable)
        ModulationOrder = 4;
        SampleRate = 48000;
        SamplesPerSymbol = 4;
        RRCFilterSpanInSymbols = 6;
        RRCRolloffFactor = 0.75;
        DUCInterpolationFactor = 6;
        DUCStopbandAttenuation = 60;
        DUCPassbandRipple = 0.05;
        DUCCenterFrequency = 10e3;
        PreambleUniqueWord = ([+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1] + 1) / 2; % Barker 13
        PreambleCount = 2
        ScramblerPolynomial = [1 1 1 0 1]
        ScramblerInitialConditions = [0 0 0 0]
        EncoderEnabled = true
        EncoderTrellisStructure = poly2trellis(7, [171 133])
        EncoderPuncturePattern = [1; 1; 0; 1; 0; 1]
        Gain = 0.25
    end

    properties (Access=private)
        Framer
        Filter
        DUC
        EOT
    end

    methods
        function obj = Transmitter(varargin)
            setProperties(obj,nargin,varargin{:});
            obj.EOT = false;
            obj.Framer = FrameGenerator(...
                'ModulationOrder', obj.ModulationOrder, ...
                'PreambleUniqueWord', obj.PreambleUniqueWord, ...
                'PreambleCount', obj.PreambleCount, ...
                'ScramblerPolynomial', obj.ScramblerPolynomial, ...
                'ScramblerInitialConditions', obj.ScramblerInitialConditions, ...
                'EncoderEnabled', obj.EncoderEnabled, ...
                'EncoderTrellisStructure', obj.EncoderTrellisStructure, ...
                'EncoderPuncturePattern', obj.EncoderPuncturePattern);
            obj.Filter = comm.RaisedCosineTransmitFilter(...
                'RolloffFactor', obj.RRCRolloffFactor, ...
                'FilterSpanInSymbols', obj.RRCFilterSpanInSymbols, ...
                'OutputSamplesPerSymbol', obj.SamplesPerSymbol);
            obj.DUC = dsp.DigitalUpConverter(...
                'InterpolationFactor', obj.DUCInterpolationFactor, ...
                'SampleRate', obj.SampleRate / obj.DUCInterpolationFactor, ...
                'Bandwidth', obj.SampleRate / obj.DUCInterpolationFactor / obj.SamplesPerSymbol, ...
                'StopbandAttenuation', obj.DUCStopbandAttenuation, ...
                'PassbandRipple', obj.DUCPassbandRipple, ...
                'CenterFrequency', obj.DUCCenterFrequency);
        end

        function setEOT(obj)
            obj.EOT = true;
        end
    end

    methods (Access=protected)
        function resetImpl(obj)
            obj.EOT = false;
            reset(obj.Framer);
            reset(obj.Filter);
            reset(obj.DUC);
        end

        function releaseImpl(obj)
            obj.EOT = false;
            release(obj.Framer);
            release(obj.Filter);
            release(obj.DUC);
        end

        function passband = stepImpl(obj, payload)
            frame = step(obj.Framer, payload);
            if obj.EOT
                % Flush the transmit filter
                frame = complex(zeros(size(frame)));
                obj.EOT = false;
            end
            baseband = step(obj.Filter, frame);
            passband = obj.Gain * step(obj.DUC, baseband);
        end

    end
end

