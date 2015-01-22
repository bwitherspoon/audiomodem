Summary
==========

AudioModem is a narrowband digital transmitter and receiver
implemented using MATLAB®. It is intended to be a demonstration of a
practical system and not a simulation. Using single carrier QAM
digital modulation, an image can be transmitted from one computer to
another with a typical audio card, speaker and microphone. The
performance will vary depending on your hardware. Typically a bitrate
of 8 kbit/s can be achieved.

Features
========

This transceiver demonstrates the following digital communication
concepts:

- Digital modulation
    - BPSK (preamble only)
    - QPSK
    - 16-QAM (not reliable)
    - 64-QAM (not reliable)
- Convolutional coding
    - 1/2 rate without puncturing
    - 2/3 rate with puncturing
    - 3/4 rate with puncturing
- Interleaving
- Scrambling
- Timing synchronization
- Phase synchronization
- Frame synchronization

Dependencies
============

A recent version of MATLAB is required and only version 2014a and
2014b have been tested. In addition, this project uses [System
objects][systemobjects]™ extensively. Therefore, the Communications
Systems Toolbox and DSP System Toolbox are also required.

[systemobjects]: http://www.mathworks.com/help/dsp/basic-operations.html

Usage
=====

Quick Start
-----------

When running any of the provided examples an open file dialog will
appear on the transmitter for you to select an image for transfer.  On
the receiver a constellation and spectrum plot will be shown. After the
file transfer is complete the received image will be displayed. Some
status messages will be printed to the console. A warning will be
printed if the CRC checksum for the image is not correct.

To run a simple loop back simulation execute *runSimulateImage.m*
from a MATLAB command prompt:

    >> runSimulateImage

To transfer an image execute *runReceiveImage.m*:

    >> runReceiveImage

Then from another computer execute *runTransmitImage.m*:

    >> runTransmitImage

It is suggested you run the transmitter and receiver applications on
separate computers. It is certainly possible to run two separate
MATLAB instances on the same computer, but most audio cards have
significant internal leakage between the input and output paths
causing the SNR to be much higher then in a realistic scenario.

Configuration
-------------

All of the examples provided use the *SystemConfiguration* function to
return a structure of configuration parameters. Have a look at this
file and edit only the basic configuration parameters unless you know
what you are doing. Note that almost all of the parameters correspond
to options of the MATLAB provided System objects used in the system.

Details
=======

The system is implemented using custom and MATLAB provided System
objects. Below are some short descriptions of each and some
delightful flow graphs.

![System][system]

Transmitter
-----------

The transmitter class implements transmit physical layer (PHY). The
input is the payload to be transmitted as a column vector of bytes and
the output is the complex baseband samples that are to be transmitted.
The transmitter consists of a frame generator, root-raised cosine
(RRC) pulse shaping filter and a digital upconverter (DUC).

![Transmitter][transmitter]

Receiver
--------

The receiver class implements the receive physical layer. The data
flow is essentially the reverse of the transmitter, but with the added
complexity of synchronization. The receiver consists of a digital
downconverter (DDC), an RRC matched filter, a symbol timing
synchronizer and a frame synchronizer.

![Receiver][receiver]

[system]: http://www.cae.tntech.edu/~cbwithersp42/audiomodem/system.svg
[transmitter]: http://www.cae.tntech.edu/~cbwithersp42/audiomodem/transmitter.svg
[receiver]: http://www.cae.tntech.edu/~cbwithersp42/audiomodem/receiver.svg

