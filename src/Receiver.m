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

classdef Receiver < matlab.System
    % A QAM receive path PHY layer.
    %
    % The input is a column vector of complex baseband samples.
    %
    % The output is a column vector of bytes or bits.
    %
    % See README.md for details.

    properties (Nontunable)
        ModulationOrder = 4;
        BitOutput = false;
        SampleRate = 48000;
        SamplesPerSymbol = 4;
        RRCFilterSpanInSymbols = 6;
        RRCRolloffFactor = 0.75;
        DDCDecimationFactor = 6;
        DDCStopbandAttenuation = 60;
        DDCPassbandRipple = 0.05;
        DDCCenterFrequency = 10e3;
        PreambleUniqueWord = ([+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1] + 1) / 2; % Barker 13
        PreambleCount = 2
        PreambleThreshold = 1
        DescramblerPolynomial = [1 1 1 0 1]
        DescramblerInitialConditions = [0 0 0 0]
        DecoderEnabled = true
        DecoderTrellisStructure = poly2trellis(7, [171 133])
        DecoderPuncturePattern = [1; 1; 0; 1; 0; 1]
        DecoderTracebackDepth = 96;
        TimingErrorUpdateGain = 1 / 8;
        ShowConstellation = false;
        ShowSpectrum = false;
    end

    properties (Access=private)
        DDC
        Filter
        Timing
        Deframer
        AGC
        Constellation
        Spectrum
        Scope
    end

    methods
        function obj = Receiver(varargin)
            setProperties(obj,nargin,varargin{:});
            obj.DDC = dsp.DigitalDownConverter(...
                'DecimationFactor', obj.DDCDecimationFactor, ...
                'SampleRate', obj.SampleRate, ...
                'Bandwidth', obj.SampleRate / obj.DDCDecimationFactor / obj.SamplesPerSymbol, ...
                'StopbandAttenuation', obj.DDCStopbandAttenuation, ...
                'PassbandRipple', obj.DDCPassbandRipple, ...
                'CenterFrequency', obj.DDCCenterFrequency);
            obj.Filter = comm.RaisedCosineReceiveFilter(...
                'RolloffFactor', obj.RRCRolloffFactor, ...
                'FilterSpanInSymbols', obj.RRCFilterSpanInSymbols, ...
                'InputSamplesPerSymbol', obj.SamplesPerSymbol, ...
                'DecimationFactor', 1);
            obj.Timing = comm.GardnerTimingSynchronizer(...
                'SamplesPerSymbol', obj.SamplesPerSymbol, ...
                'ErrorUpdateGain', obj.TimingErrorUpdateGain);
            obj.Deframer = FrameSynchronizer(...
                'ModulationOrder', obj.ModulationOrder, ...
                'BitOutput', obj.BitOutput, ...
                'PreambleUniqueWord', obj.PreambleUniqueWord, ...
                'PreambleCount', obj.PreambleCount, ...
                'PreambleThreshold', obj.PreambleThreshold, ...
                'DescramblerPolynomial', obj.DescramblerPolynomial, ...
                'DescramblerInitialConditions', obj.DescramblerInitialConditions, ...
                'DecoderEnabled', obj.DecoderEnabled, ...
                'DecoderTrellisStructure', obj.DecoderTrellisStructure, ...
                'DecoderPuncturePattern', obj.DecoderPuncturePattern, ...
                'DecoderTracebackDepth', obj.DecoderTracebackDepth);
            obj.AGC = comm.AGC(...
                'UpdatePeriod', 2, ...
                'StepSize', 0.05);
            obj.Spectrum = dsp.SpectrumAnalyzer(...
                'SampleRate', obj.SampleRate, ...
                'PlotAsTwoSidedSpectrum', false);
            obj.Constellation = comm.ConstellationDiagram;
        end
    end

    methods (Access=protected)
        function resetImpl(obj)
            reset(obj.DDC);
            reset(obj.Filter);
            reset(obj.Timing);
            reset(obj.Deframer);
            reset(obj.AGC);
            reset(obj.Spectrum);
            reset(obj.Constellation);
        end

        function releaseImpl(obj)
           release(obj.DDC);
           release(obj.Filter);
           release(obj.Timing);
           release(obj.Deframer);
           release(obj.AGC);
           release(obj.Spectrum);
           release(obj.Constellation);
        end

        function payload = stepImpl(obj, passband)
            baseband = step(obj.DDC, passband);
            filtered = step(obj.Filter, baseband);
            [symbols, ~] = step(obj.Timing, filtered);
            [payload_symbols, payload] = step(obj.Deframer, symbols);

            if obj.ShowConstellation
                payload_symbols = 0.75*step(obj.AGC, payload_symbols);
                step(obj.Constellation, payload_symbols);
            end
            if obj.ShowSpectrum
                step(obj.Spectrum, passband);
            end
        end
    end
end

