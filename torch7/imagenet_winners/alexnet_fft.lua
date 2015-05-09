function alexnet(lib)
   local SpatialConvolution = lib[1]
   local SpatialMaxPooling = lib[2]
   local ReLU = lib[3]
   local SpatialZeroPadding = nn.SpatialZeroPadding
   local padding = true
   local stride1only = false
   local reuse
   if lib[5] == 'fbfft' then
      stride1only = true -- fbfft does not support convolutions that are not stride-1
      reuse = 'all'
   end

   -- from https://code.google.com/p/cuda-convnet2/source/browse/layers/layers-imagenet-1gpu.cfg
   -- this is AlexNet that was presented in the One Weird Trick paper. http://arxiv.org/abs/1404.5997
   local features = nn.Sequential()
   if stride1only then
      features:add(cudnn.SpatialConvolution(3,64,11,11,4,4,2,2))
   else
      features:add(SpatialConvolution(3,64,11,11,4,4,2,2))       -- 224 -> 55
   end
   features:add(ReLU(true))
   features:add(SpatialMaxPooling(3,3,2,2))                   -- 55 ->  27
   features:add(nn.SpatialConvolutionFBFFT(64,192,5,5,1,1,2,2,'all'))       --  27 -> 27
   features:add(ReLU(true))
   features:add(SpatialMaxPooling(3,3,2,2))                   --  27 ->  13
   features:add(nn.SpatialConvolutionFBFFTGemm(192,384,3,3,1,1,1,1,reuse))      --  13 ->  13
   features:add(ReLU(true))
   features:add(nn.SpatialConvolutionFBFFTGemm(384,256,3,3,1,1,1,1,reuse))      --  13 ->  13
   features:add(ReLU(true))
   features:add(nn.SpatialConvolutionFBFFTGemm(256,256,3,3,1,1,1,1,reuse))      --  13 ->  13
   features:add(ReLU(true))
   features:add(SpatialMaxPooling(3,3,2,2))                   -- 13 -> 6

   local classifier = nn.Sequential()
   classifier:add(nn.View(256*6*6))
   -- classifier:add(nn.Dropout(0.5))
   classifier:add(nn.Linear(256*6*6, 4096))
   classifier:add(nn.Threshold(0, 1e-6))
   -- classifier:add(nn.Dropout(0.5))
   classifier:add(nn.Linear(4096, 4096))
   classifier:add(nn.Threshold(0, 1e-6))
   classifier:add(nn.Linear(4096, 1000))
   -- classifier:add(nn.LogSoftMax())

   local model = nn.Sequential()
   model:add(features):add(classifier)

   return model,'AlexNet',{128,3,224,224}
end

return alexnet
