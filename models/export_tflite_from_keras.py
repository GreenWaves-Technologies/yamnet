from tensorflow.keras import layers, Model
import tensorflow as tf
import params as yamnet_params
import yamnet as yamnet_model
import tensorflow as tf

params = yamnet_params.Params(sample_rate=16000, patch_hop_seconds=0.1)
print("Sample rate =", params.sample_rate)

features = layers.Input(dtype=tf.float32, shape=(96, 64, 1))
predictions, embeddings = yamnet_model.yamnet(features, params)
yamnet_nn = Model(name='yamnet', inputs=features, outputs=[predictions])
yamnet_nn.load_weights("models/yamnet.h5")

converter = tf.lite.TFLiteConverter.from_keras_model(yamnet_nn)
tflite_model = converter.convert()
with open("models/yamnet.tflite", 'wb') as f:
    f.write(tflite_model)
