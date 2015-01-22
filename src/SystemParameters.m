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

function param = SystemParameters()
% Generates a structure with audiomodem system parameters
%
% See README.md

%
% Basic parameters
%
param.SampleRate = 96000;     % Must be supported by sound card
param.ResamplingFactor = 6;   % Must be a non-prime positive integer
param.SamplesPerSymbol = 4;   % Must be a positive integer
param.ModulationOrder = 4;    % Order 4, 16, and 64 supported
param.CenterFrequency = 10e3;

if mod(param.ResamplingFactor, 1) || isprime(param.ResamplingFactor)
    error('Resampling factor must be a non-prime integer')
end

param.Verbose = true;

%
% Advanced parameters
%
param.Gain = 0.25;

% Coding
param.Coding.Enabled = true;
param.Coding.TrellisStructure = poly2trellis(7, [171 133]);
% 3/4 coding rate
% param.Coding.PuncturePattern = [1; 1; 0; 1; 0; 1];
% param.Coding.TracebackDepth = 96;
% 2/3 coding rate
param.Coding.PuncturePattern = [1; 1; 1; 0];
param.Coding.TracebackDepth = 63;
% 1/2 coding rate
% param.Coding.PuncturePattern = [1; 1; 1; 1; 1; 1];
% param.Coding.TracebackDepth = 35;
if param.Coding.Enabled
    param.Coding.Rate = (length(param.Coding.PuncturePattern)/2) / sum(param.Coding.PuncturePattern);
else
    param.Coding.Rate = 1;
end

% DUC
param.DUC.StopbandAttenuation = 60;
param.DUC.PassbandRipple = 0.05;
% param.DUC.StopbandAttenuation = 40;
% param.DUC.PassbandRipple = 0.065;

% DUC
param.DDC.StopbandAttenuation = param.DUC.StopbandAttenuation;
param.DDC.PassbandRipple = param.DUC.PassbandRipple;

% RRC
param.RRC.FilterSpanInSymbols = 6;
param.RRC.RolloffFactor = 0.9;

% Timing
param.Timing.ErrorUpdateGain = 0.05;

% Scrambling
param.Scrambling.Polynomial = [1 0 0 0 1 0 0 1];
param.Scrambling.InitialConditions = [0 0 0 0 0 0 0];

% Preamble
param.Preamble.UniqueWord = ([+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1] + 1) / 2;
param.Preamble.Count = 2;
param.Preamble.Threshold = 0;

% Framing

% Uncoded bits per frame must be a multiple of 96 (see README)
bits_per_frame = 27*96;
param.BytesPerFrame = (bits_per_frame * param.Coding.Rate) / 8 - 1;

% The samples per frame should be supported by the sound card
pre = length(param.Preamble.UniqueWord) * param.Preamble.Count;
dat = bits_per_frame / log2(param.ModulationOrder);
param.SamplesPerFrame = (pre+dat)*param.SamplesPerSymbol*param.ResamplingFactor;

% The bit rate is calculated so it can be printed for informational purposes
symbol_rate = param.SampleRate/param.SamplesPerSymbol/param.ResamplingFactor;
param.BitRate = symbol_rate*log2(param.ModulationOrder)*param.Coding.Rate;

end
