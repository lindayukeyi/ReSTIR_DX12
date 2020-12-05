/* Shade pixel */

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gMatSpec;
RWTexture2D<float4> gMatExtra;
RWTexture2D<float4> gMatEmissive;

// Reservoir texture
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit point(ref) to sample // w: distToLight
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

RWTexture2D<float4> jilin;

float4 main(float2 texC : TEXCOORD, float4 pos : SV_Position) : SV_Target0
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	if (gWsPos[pixelPos].w == 0) {
		return float4(0, 0, 0, 1);
	}

	float lambert = max(0, dot(toSample[pixelPos].xyz, gWsNorm[pixelPos].xyz));
	float3 bsdf = gMatDif[pixelPos].xyz / 3.14159265359f;
	float3 L = emittedLight[pixelPos].xyz;
	
	// Compute pdf of sampling light
	/*float pdfL = 0.f;
	float cosLight = dot(-toSample[pixelPos].xyz, sampleNormalArea[pixelPos].xyz);
	if (cosLight != 0.f && sampleNormalArea[pixelPos].w > 0) {
		float r = toSample[pixelPos].w;
		pdfL = r * r / (cosLight * sampleNormalArea[pixelPos].w);
	}*/

	float3 result = bsdf * L * lambert * reservoir[pixelPos].x;
	jilin[pixelPos] = float4(reservoir[pixelPos].xy, float(M[pixelPos]), 1);
	return float4(result, 1);
}
