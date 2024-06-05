struct RasterizerData
{
	float4 position [[position]];
	float4 color;
};

constant float2 positions[] = {{0, 1}, {-1, -1}, {1, -1}};

vertex RasterizerData
VertexFunction(uint vertex_id [[vertex_id]], constant float2 *resolution, constant float *size)
{
	RasterizerData output = {0};
	output.position.xy = positions[vertex_id] * *size / *resolution;
	output.position.w = 1;
	output.color = float4(1, 1, 1, 1);
	return output;
}

fragment float4
FragmentFunction(RasterizerData input [[stage_in]])
{
	return input.color;
}
