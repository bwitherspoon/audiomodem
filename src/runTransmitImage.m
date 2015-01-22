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

function runTransmitImage()
% Transmits an image
%
% See README.md

param = SystemParameters();

fprintf('Bitrate: %.1f\n', param.BitRate);
fprintf('Samples per frame %d\n', param.SamplesPerFrame);
fprintf('Bytes per frame %d\n', param.BytesPerFrame);

if audiodevinfo(0, param.SampleRate, 16, 1) == -1
    error('Audio card and/or sampling rate not supported');
end

% System objects
Src = ImageSource(...
    'Verbose', true, ...
    'BytesPerFrame', param.BytesPerFrame, ...
    'ShowImage', false);
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
    'EncoderPuncturePattern', param.Coding.PuncturePattern, ...
    'Gain', param.Gain);
Sink = dsp.AudioPlayer(...
    'SampleRate', param.SampleRate);

% Dummy frames to aid timing synchronization
for i = 1:2
    dummy = randi([0, 255], param.BytesPerFrame, 1, 'uint8');
    passband = Tx.step(dummy);
    Sink.step(passband);
end

% Loop until source is done
while ~Src.isDone()
    frame = Src.step();
    passband = Tx.step(frame);
    Sink.step(passband);
end

Tx.setEOT();

% Dummy to clear transmit filter taps after EOT (dummy is not transmitted)
passband = Tx.step(dummy);
Sink.step(passband);

pause(Audio.QueueDuration);
release(Src);
release(Audio);
release(Tx);

fprintf('Image transmitted\n');

end
