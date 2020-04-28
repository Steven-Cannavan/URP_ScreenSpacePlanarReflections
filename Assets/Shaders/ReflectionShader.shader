Shader "Hidden/ReflectionShader"
{
	Properties
	{
		[IntRange] _StencilRef("Stencil Reference Value", Range(0,255)) = 0
	}

	SubShader
	{
		Tags{ "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}


		HLSLINCLUDE

	#pragma prefer_hlslcc gles
		#pragma exclude_renderers d3d11_9x
		//Keep compiler quiet about Shadows.hlsl.
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
		//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
		//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
		float4 _SSPRBufferRange;

#if SHADER_API_METAL
        uint _SSPRBufferStride;
        uint GetIndex(uint2 id)
        {
			return ((id.y / 4) * _SSPRBufferStride + (id.x / 4) * 16) + ((id.y % 4) * 4) + (id.x % 4);

			//return id.y * _SSPRBufferRange.x + id.x;
        }

        Buffer<uint> _ScreenSpacePlanarReflectionBuffer;

#define LOAD(pixel) _ScreenSpacePlanarReflectionBuffer.Load(GetIndex(pixel))
#else
		Texture2D<uint> _ScreenSpacePlanarReflectionBuffer;
#define LOAD(pixel) _ScreenSpacePlanarReflectionBuffer.Load(int3(pixel.x, pixel.y, 0))
#endif
		

		
		//TEXTURE2D_X(_CameraColorAttachment);
		TEXTURE2D_X(_MainTex);
		SAMPLER(sampler_MainTex);
		float4 _MainTex_TexelSize;
		SAMPLER(sampler_LinearClamp);
		SAMPLER(sampler_PointClamp);


		struct Attributes
		{
			float4 positionOS   : POSITION;
			float2 texcoord : TEXCOORD0;
			UNITY_VERTEX_INPUT_INSTANCE_ID
		};

		struct Varyings
		{
			half4  positionCS   : SV_POSITION;
			half4  uv           : TEXCOORD0;
			UNITY_VERTEX_OUTPUT_STEREO
		};

		Varyings Vertex(Attributes input)
		{
			Varyings output;
			UNITY_SETUP_INSTANCE_ID(input);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

			output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

			float4 projPos = output.positionCS * 0.5;
			projPos.xy = projPos.xy + projPos.w;

			output.uv.xy = UnityStereoTransformScreenSpaceTex(input.texcoord);
			output.uv.zw = projPos.xy;

			return output;
		}


		half4 RenderFragment(Varyings input) : SV_Target
		{
			uint Hash = LOAD(int2(input.uv.x * _SSPRBufferRange.x, input.uv.y * _SSPRBufferRange.y)); //_ScreenSpacePlanarReflectionBuffer.Load(int3(input.uv.x * _SSPRBufferRange.x, input.uv.y * _SSPRBufferRange.y, 0));

#if UNITY_UV_STARTS_AT_TOP
			if (Hash == 0xFFFFFFFF)
			{
#else
			if (Hash == 0)
			{
#endif
				return half4(0, 0, 0, 0);
			}

			float2 uv = float2((Hash & 0xFFFF) / _SSPRBufferRange.x, (Hash >> 16) / _SSPRBufferRange.y);

			float4 value = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv);

			// Y fade
#if UNITY_UV_STARTS_AT_TOP
			value.a = (1.0 - uv.y) * 10.0;
#else
			value.a = uv.y * 10.0;
#endif

			return value;
		}

		static const float Weights[] = {0.0625, 0.125, 0.0625,0.0125, 0.25, 0.125 ,0.0625, 0.125, 0.0625 };
		static const float2 Offsets[] = { float2(-1,1),float2(0,1),float2(1,1),float2(-1,0),float2(0,0),float2(1,0), float2(-1,-1),float2(0,-1),float2(1,-1) };
		half4 BlurFragment(Varyings input) : SV_Target
		{
			float TotalWeight = 0.0;
			float4 Total = float4(0.0, 0.0, 0.0, 0.0);
			

			// Simple guassian blur but we look at the alpha to affect the weights
			[unroll]
			for (int i = 0; i < 9; i++)
			{
				float4 value = SAMPLE_TEXTURE2D_X(_MainTex, sampler_PointClamp, input.uv + Offsets[i] * _MainTex_TexelSize.xy);
				Total += value * Weights[i];
				TotalWeight += (value.a > 0 ? 1 : 0) * Weights[i];
			}
			
			// Adjust the value by the number of 'invalid samples' to make sure were a 'normalized' sample
			Total /= TotalWeight;

			// if we have a weight above 0.125 we will treat it as a solid opaque pixel
			// otherwise we only a contribution from the very corner pieces of the 3x3 filter so we probably can ignore that
			Total.a *= TotalWeight >= 0.125 ? 1.0 : 0.0;

			return Total;
		}


		ENDHLSL

		Pass
		{
			Name "ScreenSpacePlanarReflection"
			ZTest Always
			ZWrite Off
			Cull Off
			HLSLPROGRAM
			
			#pragma enable_d3d11_debug_symbols
			#pragma multi_compile COLOR_ATTACHMENT
			#pragma multi_compile _NO_MSAA _MSAA_2 _MSAA_4
			#pragma vertex   Vertex
			#pragma fragment RenderFragment
			ENDHLSL
		}

		Pass
		{
			Name "ScreenSpacePlanarReflection"
			ZTest Always
			ZWrite Off
			Cull Off
			HLSLPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma vertex   Vertex
			#pragma fragment BlurFragment
			ENDHLSL
		}

		Pass
		{
			Name "ScreenSpacePlanarReflection"
			ZTest Always
			ZWrite Off
			Cull Off

			Stencil{
				Ref[_StencilRef]
				Comp Equal
			}

			HLSLPROGRAM

			#pragma enable_d3d11_debug_symbols
			#pragma multi_compile COLOR_ATTACHMENT
			#pragma multi_compile _NO_MSAA _MSAA_2 _MSAA_4
			#pragma vertex   Vertex
			#pragma fragment RenderFragment
			ENDHLSL
		}

		Pass
		{
			Name "ScreenSpacePlanarReflection"
			ZTest Always
			ZWrite Off
			Cull Off

			Stencil{
				Ref[_StencilRef]
				Comp Equal
			}

			HLSLPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma vertex   Vertex
			#pragma fragment BlurFragment
			ENDHLSL
		}
    }
}
