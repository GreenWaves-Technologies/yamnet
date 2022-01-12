YAMNet
=====


This project contains an implementation on GAP processor of YAMNet_ specialized for inference on mobile devices with the following changes:

The model is quantized. This required retraining the model with Relu6 non-linearities instead of Relu, to limit activation ranges.

The inference signature is simpler. We now take a single fixed-length frame of audio (15600 samples) and return a single vector of scores for 521 audio event classes.

Please refer to the original YAMNet_ for more information about the model description, as well as suitable uses and limitations.

TFLITE reference Project: `Tensor Flow Hub project`_


Inputs
-----

The model accepts a 1-D float32 Tensor or NumPy array of length 15600 containing a 0.975 second waveform represented as mono 16 kHz samples in the range [-1.0, +1.0].

Outputs
-----

The model returns a 2-D float32 Tensor of shape (1, 521) containing the predicted scores for each of the 521 classes in the AudioSet ontology that are supported by YAMNet. The column index (0-520) of the scores tensor is mapped to the corresponding AudioSet class name using the YAMNet Class Map, which is available as an associated file yamnet_label_list.txt packed into the model file. See below for usage.


.. _YAMNet: https://tfhub.dev/google/yamnet/1
.. _Tensor Flow Hub project: https://tfhub.dev/google/lite-model/yamnet/classification/tflite/1