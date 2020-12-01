ReSTIR with DirectX Raytracing
================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Final Project**

* Jilin Liu
  * [LinkedIn](https://www.linkedin.com/in/jilin-liu97/), [twitter](https://twitter.com/Jilin18043110).
* Keyi Yu
  * [LinkedIn](https://www.linkedin.com/in/keyi-linda-yu-8b1178137/).
* Li Zheng
  * [LinkedIn](https://www.linkedin.com/in/li-zheng-1955ba169/).

![](compare.png)

## Introduction

This repository contains our implementation of Reservoir-based SpatioTemporal Importance Resampling(i.e. ReSTIR) with DirectX Raytracing. Our base code is from Chris Wyman's DXR tutorials ["A Gentle Introduction To DirectX Raytracing"](http://cwyman.org/code/dxrTutors/dxr_tutors.md.html). He is also one of the authors of our reference paper. The code is dependent on Nvidia's [Falcor](https://developer.nvidia.com/falcor) framework.

## Pipeline Overview

Our pipeline is comprised of 5 passes. The first two use the raytracing shader while others use the pixel shader.

1. **Raytraced G-Buffer and RIS**. In the beginning, we use DXR to shoot rays from camera and collect G-Buffer informations. We also use a reservoir for each pixel to store the resampled importance sampling results. G-Buffer and rur reservoirs are encoded and stored in textures that can be shared with following passes. For now our scene only contains point lights so we randomly select a light from the scene to generate a single sample.

2. **Raytraced Visibility Test**. In the second pass, we shoot one shadow ray per pixel for our selected candidate in the first pass. If the sample is occluded from our reference point, the weight in the reservoir will be set to zero so that the current pixel cannot get contribution from that light sample.

3. **Temporal Reuse Pixel Shader**. From this pass, we start using pixel shader, which only reads from textures and do some calculation. Given the hit point(reference point) of current pixel, we multiply it by previous frame's view-projection matrix to get the corresponding pixel position in last frame. We then combine the current reservoir with the reservoir of that corresponding pixel to reuse samples from last frame.

4. **Spatial Reuse Pixel Shader**. In this pass, we combine the current reservoir with several reservoirs in a neighborhood in screen space. Given the adjacent pixel usually share similar lighting conditions and occlusions, this step makes it possible to reuse a lot of good samples. However, it also introduces bias. Currently, our ReSTIR is the biased version. We only reduce the bias by rejecting neighbor's reservoir when normal difference or depth difference exceeds some threshold.

5. **Shade Pixel**. The final step utilizes the reservoir and G-Buffer from previous passes and shade the current pixel to get the final image.

## Acknowledgements

The desert HDR environment map (MonValley Dirtroad) is provided from the sIBL Archive under a 
Creative Commons license (CC BY-NC-SA 3.0 US). See
    http://www.hdrlabs.com/sibl/archive.html 

The included "pink_room" scene is named 'The Modern Living Room' by Wig42 on Benedikt Bitterli's
webpage (https://benedikt-bitterli.me/resources/).  It has been modified to match the Falcor 
material system.  This scene was released under a CC-BY license.  It may be copied, modified and 
used commercially without permission, as long as: Appropriate credit is given to the original author
The original scene file may be obtained here: 
    http://www.blendswap.com/blends/view/75692
