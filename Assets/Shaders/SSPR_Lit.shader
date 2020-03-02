Shader "URPExample/SSPR_Lit"
{
    Properties
    {
        // Specular vs Metallic workflow
        [HideInInspector] _WorkflowMode("WorkflowMode", Float) = 1.0

        [MainColor] _BaseColor("Color", Color) = (0.5,0.5,0.5,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        _SmoothnessTextureChannel("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        _SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
        _SpecGlossMap("Specular", 2D) = "white" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        // Blending state
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0

        _ReceiveShadows("Receive Shadows", Float) = 1.0
        // Editmode props
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0

        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        [HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
        [HideInInspector] _Glossiness("Smoothness", Float) = 0.0
        [HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0
    }

    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 300

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _OCCLUSIONMAP

            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex CustomLitPassVertex
            #pragma fragment CustomLitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"

			TEXTURE2D(_ScreenSpacePlanarReflectionTexture);       
			SAMPLER(sampler_ScreenSpacePlanarReflectionTexture);

			struct VaryingsCustom
			{
				float2 uv                       : TEXCOORD0;
				DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

#ifdef _ADDITIONAL_LIGHTS
				float3 positionWS               : TEXCOORD2;
#endif

#ifdef _NORMALMAP
				float4 normalWS                 : TEXCOORD3;    // xyz: normal, w: viewDir.x
				float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: viewDir.y
				float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
#else
				float3 normalWS                 : TEXCOORD3;
				float3 viewDirWS                : TEXCOORD4;
#endif

				half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

#ifdef _MAIN_LIGHT_SHADOWS
				float4 shadowCoord              : TEXCOORD7;
#endif
				float4 screenPosition			: TEXCOORD8;
				float4 positionCS               : SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			half4 ScreenSpaceReflection(half2 uv, half3 normalWS, half occlusion, half roughness)
			{

#if UNITY_UV_STARTS_AT_TOP
				uv.y = 1 - uv.y;
#endif
				float yFade = min(uv.y * 10, 1.0);


				return SAMPLE_TEXTURE2D(_ScreenSpacePlanarReflectionTexture, sampler_ScreenSpacePlanarReflectionTexture, uv) * occlusion * (yFade*yFade);
			}

			half3 GlobalIlluminationWithPlanarReflection(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS, half2 uv)
			{
				half3 reflectVector = reflect(-viewDirectionWS, normalWS);
				half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

				half3 indirectDiffuse = bakedGI * occlusion;
				half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion);
				/*
				indirectSpecular = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
				half4 sspr = ScreenSpaceReflection(uv, normalWS, occlusion, fresnelTerm);
				return lerp(indirectSpecular, sspr.rgb, sspr.a);
				*/
				half4 sspr = ScreenSpaceReflection(uv, normalWS, occlusion, fresnelTerm);
				indirectSpecular = lerp(indirectSpecular, sspr.rgb, sspr.a);

				return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);;
			}

			half4 CustomUniversalFragmentPBR(InputData inputData, half3 albedo, half metallic, half3 specular,
				half smoothness, half occlusion, half3 emission, half alpha, half2 ScreenPos)
			{
				BRDFData brdfData;
				InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

				Light mainLight = GetMainLight(inputData.shadowCoord);
				MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

				half3 color = GlobalIlluminationWithPlanarReflection(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS, ScreenPos);
				color += LightingPhysicallyBased(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);

			#ifdef _ADDITIONAL_LIGHTS
				uint pixelLightCount = GetAdditionalLightsCount();
				for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
				{
					Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
					color += LightingPhysicallyBased(brdfData, light, inputData.normalWS, inputData.viewDirectionWS);
				}
			#endif

			#ifdef _ADDITIONAL_LIGHTS_VERTEX
				color += inputData.vertexLighting * brdfData.diffuse;
			#endif

				color += emission;
				return half4(color, alpha);
			}

			// Used in Standard (Physically Based) shader
			VaryingsCustom CustomLitPassVertex(Attributes input)
			{
				VaryingsCustom output = (VaryingsCustom)0;

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
				half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
				half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
				half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

#ifdef _NORMALMAP
				output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
				output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
				output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
#else
				output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
				output.viewDirWS = viewDirWS;
#endif

				OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
				OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

				output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#ifdef _ADDITIONAL_LIGHTS
				output.positionWS = vertexInput.positionWS;
#endif

#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
				output.shadowCoord = GetShadowCoord(vertexInput);
#endif

				output.positionCS = vertexInput.positionCS;
				output.screenPosition = vertexInput.positionCS;


				return output;
			}

			void InitializeCustomInputData(VaryingsCustom input, half3 normalTS, out InputData inputData)
			{
				inputData = (InputData)0;

#ifdef _ADDITIONAL_LIGHTS
				inputData.positionWS = input.positionWS;
#endif

#ifdef _NORMALMAP
				half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
				inputData.normalWS = TransformTangentToWorld(normalTS,
					half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
#else
				half3 viewDirWS = input.viewDirWS;
				inputData.normalWS = input.normalWS;
#endif

				inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
				viewDirWS = SafeNormalize(viewDirWS);

				inputData.viewDirectionWS = viewDirWS;
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
				inputData.shadowCoord = input.shadowCoord;
#else
				inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
				inputData.fogCoord = input.fogFactorAndVertexLight.x;
				inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
				inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
			}


			// Used in Standard (Physically Based) shader
			half4 CustomLitPassFragment(VaryingsCustom input) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				SurfaceData surfaceData;
				InitializeStandardLitSurfaceData(input.uv, surfaceData);

				InputData inputData;
				InitializeCustomInputData(input, surfaceData.normalTS, inputData);

				float2 ScreenUV = input.screenPosition.xy / input.screenPosition.w;
				ScreenUV = float2(0.5, 0.5) + ScreenUV * float2(0.5, 0.5);

				half4 color = CustomUniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha, ScreenUV);

				color.rgb = MixFog(color.rgb, inputData.fogCoord);
				return color;
			}



            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMeta

            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature _SPECGLOSSMAP

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
        Pass
        {
            Name "Universal2D"
            Tags{ "LightMode" = "Universal2D" }

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Universal2D.hlsl"
            ENDHLSL
        }


    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShader"
}
