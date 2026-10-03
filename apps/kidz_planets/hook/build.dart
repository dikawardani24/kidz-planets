import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    buildScenes(
      buildInput: input,
      buildOutput: output,
      // The avatar rocket carries 2048x2048 base color and metallic-roughness
      // atlases. Stored raw they made the cooked scene about 17 MB, so they go
      // in as supercompressed block payloads that transcode to whatever format
      // the device GPU wants. 2048 is a multiple of the 4x4 block size, so no
      // resampling is needed; a source that is not block aligned would be stored
      // uncompressed and named in the hook log.
      compressTextures: true,
      alignForCompression: false,
    );
  });
}
