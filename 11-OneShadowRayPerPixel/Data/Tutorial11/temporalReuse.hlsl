/* Temporal Reuse */

#include "pbr.hlsli"

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;

// Reservoir texture
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit point(ref) to sample // w: distToLight
RWTexture2D<float4> sampleNormalArea; // xyz: sample noraml // w: area of light
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

// Last frame's reservoir texture
RWTexture2D<float4> lastEmittedLight;
RWTexture2D<float4> lastToSample;
RWTexture2D<float4> lastSampleNormalArea;
RWTexture2D<float4> lastReservoir;
RWTexture2D<int> lastM;

cbuffer MyCB {
	uint gFrameCount;
	float4x4 lastViewProjMat;
};

// TODO: move helper functions to a .hlsli file
// Generates a seed for a random number generator from 2 inputs plus a backoff
uint initRand(uint val0, uint val1, uint backoff = 16)
{
	uint v0 = val0, v1 = val1, s0 = 0;

	[unroll]
	for (uint n = 0; n < backoff; n++)
	{
		s0 += 0x9e3779b9;
		v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
		v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
	}
	return v0;
}

// Takes our seed, updates it, and returns a pseudorandom float in [0..1]
float nextRand(inout uint s)
{
	s = (1664525u * s + 1013904223u);
	return float(s & 0x00FFFFFF) / float(0x01000000);
}

struct MySample {
	float3 eL; 
	float4 tS;
	float4 sNA;
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
	if (r.Wsum_ > 0 && nextrand(seed) < (w / r.Wsum_)) {
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
	
	float w1 = evalP(r1.y_.tS.xyz, diffuse, r1.y_.eL, nor);
	updateReservoir(s, r1.y_, w1, seed);
	float w2 = evalP(r2.y_.tS.xyz, diffuse, r2.y_.eL, nor);
	updateReservoir(s, r2.y_, w2, seed);

	s.M_ = r1.M_ + r2.M_;
	s.W_ = (s.Wsum_ / s.M_) / evalP(s.y_.tS.xyz, diffuse, s.y_.eL, nor);

	return s;
}

uint2 getLastPixelPos(float4 worldPos, float width, float height, inout bool inScreen) {
	float4 ndc = mul(worldPos, lastViewProjMat);
	ndc = ndc / ndc.w;
	float2 s = (ndc.xy + float2(1, 1)) * 0.5f;
	s = float2(s.x, 1.f - s.y);
	int2 lastPos = (int2)(s * float2(widht, height));
	if (0 <= lastPos.x && lastPos.x < width && 0 <= lastPos.y && lastPos.y < height) {
		inScreen = true;
	}
	else {
		inScreen = false;
	}
	return (uint2)lastPos;
}

void main(float2 texC : TEXCOORD, float4 pos : SV_Position) {
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	float width;
	float height;
	reservoir.GetDimensions(width, height);

	// Use pixel index and frame count to initialize random seed
	uint seed = initRand(pixelPos.x + pixelPos.y * width, gFrameCount, 16);

	float4 worldPos = gWsPos[pixelPos];
	bool inScreen;
	uint2 lastPos = getLastPixelPos(worldPos, width, height, inScreen);
	if (!inScreen) {
		return;
	}

	MySample s1, s2;
	s1.eL = emittedLight[pixelPos].xyz;
	s1.tS = toSample[pixelPos];
	s1.sNA = sampleNormalArea[pixelPos];
	s2.eL = lastEmittedLight[lastPos].xyz;
	s2.tS = lastToSample[lastPos];
	s2.sNA = lastSampleNormalArea[lastPos];
	
	MyReservoir rq, rl;	
	rq.y_ = s1;
	rq.M_ = M[pixelPos];
	rq.W_ = reservoir[pixelPos].x;
	rq.Wsum_ = reservoir[pixelPos].y;
	rl.y_ = s2;
	rl.M_ = lastM[lastPos];
	rl.W_ = lastReservoir[lastPos].x;
	rl.Wsum_ = lastReservoir[lastPos].y;
	
	MyReservoir outRes = combineReservoirs(pixelPos, rq, rl, seed);
	
	emittedLight[pixelPos] = float4(outRes.y_.eL, 1.f);
	toSample[pixelPos] = outRes.y_.tS;
	sampleNormalArea[pixelPos] = outRes.y_.sNA;
	reservoir[pixelPos] = float4(outRes.W_, outRes.Wsum_, 0, 0);
	M[pixelPos] = outRes.M_;
}
