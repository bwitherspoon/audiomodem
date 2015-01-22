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

% System parameters
param = SystemParameters();

fprintf('Bitrate: %.1f\n', param.BitRate);
fprintf('Samples per frame %d\n', param.SamplesPerFrame);
fprintf('Bytes per frame %d\n', param.BytesPerFrame);

% Simulation parameters
snr = 15;
delay = 16.6498;

% System
Src = ImageSource(...
    'Verbose', true, ...
    'BytesPerFrame', param.BytesPerFrame);
Tx = Transmitter(...
    'ModulationOrder', param.ModulationOrder, ...
    'SampleRate', param.SampleRate, ...
    'SamplesPerSymbol', param.SamplesPerSymbol, ...
    'RRCFilterSpanInSymbols', param.RRC.FilterSpanInSymbols, ...
    'RRCRolloffFactor', param.RRC.RolloffFactor, ...
    'DUCInterpolationFactor', param.ResamplingFactor, ...
    'DUCStopbandAttenuation', param.DUC.StopbandAttenuation, ...
    'DUCPassbandRipple', param.DUC.PassbandRipple, ...
    'DUCCenterFrequency', param.CenterFrequency, ...
    'PreambleUniqueWord', param.Preamble.UniqueWord, ...
    'PreambleCount', param.Preamble.Count, ...
    'ScramblerPolynomial', param.Scrambling.Polynomial, ...
    'ScramblerInitialConditions', param.Scrambling.InitialConditions, ...
    'EncoderEnabled', param.Coding.Enabled, ...
    'EncoderTrellisStructure', param.Coding.TrellisStructure, ...
    'EncoderPuncturePattern', param.Coding.PuncturePattern);
Rx = Receiver(...
    'ModulationOrder', param.ModulationOrder, ...
    'BitOutput', true, ...
    'SampleRate', param.SampleRate, ...
    'SamplesPerSymbol', param.SamplesPerSymbol, ...
    'RRCFilterSpanInSymbols', param.RRC.FilterSpanInSymbols, ...
    'RRCRolloffFactor', param.RRC.RolloffFactor, ...
    'DDCDecimationFactor', param.ResamplingFactor, ...
    'DDCStopbandAttenuation', param.DDC.StopbandAttenuation, ...
    'DDCPassbandRipple', param.DDC.PassbandRipple, ...
    'DDCCenterFrequency', param.CenterFrequency, ...
    'TimingErrorUpdateGain', param.Timing.ErrorUpdateGain, ...
    'PreambleUniqueWord', param.Preamble.UniqueWord, ...
    'PreambleCount', param.Preamble.Count, ...
    'PreambleThreshold', param.Preamble.Threshold, ...
    'DescramblerPolynomial', param.Scrambling.Polynomial, ...
    'DescramblerInitialConditions', param.Scrambling.InitialConditions, ...
    'DecoderEnabled', param.Coding.Enabled, ...
    'DecoderTrellisStructure', param.Coding.TrellisStructure, ...
    'DecoderPuncturePattern', param.Coding.PuncturePattern, ...
    'DecoderTracebackDepth', param.Coding.TracebackDepth, ...
    'ShowSpectrum', false, ...
    'ShowConstellation', true);
Sink = ImageSink('Verbose', true);

% Impairments
Channel = comm.AWGNChannel(...
    'NoiseMethod', 'Signal to noise ratio (SNR)', ...
    'SNR', snr, 'SignalPower', 1/param.SamplesPerSymbol);
Delay = dsp.VariableFractionalDelay(...
    'MaximumDelay', param.SamplesPerSymbol);

% Dummy frames to aid timing synchronization
for count = 1:1
    dummy = randi([0, 255], param.BytesPerFrame, 1, 'uint8');
    txpassband = Tx.step(dummy);
    rxpassband = Channel.step(Delay.step(txpassband, delay));
    Rx.step(rxpassband);
end

% Loop until source is done
complete = false;
while ~Src.isDone()
    frame = Src.step();
    txpassband = Tx.step(frame);
    rxpassband = Channel.step(Delay.step(txpassband, delay));
    data = Rx.step(rxpassband);
    if ~isempty(data)
        complete = Sink.step(data);
    end
end

Tx.setEOT();

% Loop until sink is done
% TODO: add timeout since this could be an infinite loop
while ~complete
    ignored = uint8(randi([0, 255], param.BytesPerFrame, 1));
    txpassband = Tx.step(ignored);
    rxpassband = Channel.step(Delay.step(txpassband, delay));
    data = Rx.step(rxpassband);
    if ~isempty(data)
        complete = Sink.step(data);
    end
end
