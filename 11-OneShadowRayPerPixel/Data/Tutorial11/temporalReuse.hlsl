/* Temporal Reuse */

#include "pbr.hlsli"
#include "randomHelper.hlsli"

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;

// Reservoir texture
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit point(ref) to sample // w: distToLight
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

// Last frame's reservoir texture and world position
RWTexture2D<float4> lastEmittedLight;
RWTexture2D<float4> lastToSample;
RWTexture2D<float4> lastReservoir;
RWTexture2D<int> lastM;

RWTexture2D<float4> lastWPos;

RWTexture2D<float4> jilin; // Debug

cbuffer MyCB {
	uint gFrameCount;
	float4x4 lastViewProjMat;
};

struct MySample {
	float3 eL; 
	float4 tS;
};

struct MyReservoir {
	MySample y_;
	int M_;
	float W_;
	float Wsum_;
};

void updateReservoir(inout MyReservoir r, MySample s, float w, inout uint seed) {
	r.Wsum_ = r.Wsum_ + w;
	r.M_ = r.M_ + 1;
	if (r.Wsum_ > 0 && nextRand(seed) < (w / r.Wsum_)) {
		r.y_ = s;
	}
}

MyReservoir combineReservoirs(uint2 pixelPos, MyReservoir r1, MyReservoir r2, inout uint seed) {
	MyReservoir s;
	s.M_ = 0;
	s.W_ = 0;
	s.Wsum_ = 0;

	float3 diffuse = gMatDif[pixelPos].xyz;
	float3 nor = gWsNorm[pixelPos].xyz;
	
	float w1 = evalP(r1.y_.tS.xyz, diffuse, r1.y_.eL, nor) * r1.W_ * (float)r1.M_;
	updateReservoir(s, r1.y_, w1, seed);
	float w2 = evalP(r2.y_.tS.xyz, diffuse, r2.y_.eL, nor) * r2.W_ * (float)r2.M_;
	updateReservoir(s, r2.y_, w2, seed);

	s.M_ = r1.M_ + r2.M_;
	float p_hat = evalP(s.y_.tS.xyz, diffuse, s.y_.eL, nor);
	if (p_hat == 0) {
		s.W_ = 0;
	}
	else {
		s.W_ = (s.Wsum_ / s.M_) / p_hat;
	}

	return s;
}

uint2 getLastPixelPos(float4 worldPos, float width, float height, inout bool inScreen) {
	float4 ndc = mul(worldPos, lastViewProjMat);
	ndc = ndc / ndc.w;
	float2 s = (ndc.xy + float2(1, 1)) * 0.5f;
	s = float2(s.x, 1.f - s.y);
	int2 lastPos = (int2)(s * float2(width, height));
	if (0 <= lastPos.x && lastPos.x < width && 0 <= lastPos.y && lastPos.y < height) {
		inScreen = true;
	}
	else {
		inScreen = false;
	}
	return (uint2)lastPos;
}

void main(float2 texC : TEXCOORD, float4 pos : SV_Position)
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	float width;
	float height;
	reservoir.GetDimensions(width, height);

	float4 worldPos = gWsPos[pixelPos];
	if (worldPos.w == 0) { // This pixel is out of scene
		return;
	}

	bool inScreen;
	uint2 lastPos = getLastPixelPos(worldPos, width, height, inScreen);
	if (!inScreen) { // The corresponding pixel in previous frame is out of screen
		return;
	}

	if (length(worldPos - lastWPos[lastPos]) > 0.01f) { // The corresonding fragment is occluded by another fragment
		return;
	}
	
	if (lastReservoir[lastPos].x == 0) {
		return;
	}

	// Use pixel index and frame count to initialize random seed
	uint seed = initRand(pixelPos.x + pixelPos.y * width, gFrameCount, 16);

	MySample s1, s2;
	s1.eL = emittedLight[pixelPos].xyz;
	s1.tS = toSample[pixelPos];
	s2.eL = lastEmittedLight[lastPos].xyz;
	s2.tS = lastToSample[lastPos];
	
	MyReservoir rq, rl;	
	rq.y_ = s1;
	rq.M_ = M[pixelPos];
	rq.W_ = reservoir[pixelPos].x;
	rq.Wsum_ = reservoir[pixelPos].y;
	rl.y_ = s2;
	rl.M_ = lastM[lastPos];
	rl.W_ = lastReservoir[lastPos].x;
	rl.Wsum_ = lastReservoir[lastPos].y;

	if (rl.M_ > 20 * rq.M_) {
		rl.Wsum_ *= 20 * rq.M_ / rl.M_;
		rl.M_ = 20 * rq.M_;
	}
		
	MyReservoir outRes = combineReservoirs(pixelPos, rq, rl, seed);
	
	emittedLight[pixelPos] = float4(outRes.y_.eL, 1.f);
	toSample[pixelPos] = outRes.y_.tS;
	reservoir[pixelPos] = float4(outRes.W_, outRes.Wsum_, 0, 0);
	M[pixelPos] = outRes.M_;
}
