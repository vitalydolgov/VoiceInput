import AVFoundation

class AudioEncoder {
    func encodeToWAV(buffers: [AVAudioPCMBuffer]) -> Data {
        guard !buffers.isEmpty, let inputFormat = buffers.first?.format else {
            return Data()
        }

        let totalFrames = buffers.reduce(0) { $0 + AVAudioFrameCount($1.frameLength) }

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: inputFormat.sampleRate,
            channels: inputFormat.channelCount,
            interleaved: true
        ) else {
            return Data()
        }

        var pcmData = Data()
        pcmData.reserveCapacity(Int(totalFrames) * 2 * Int(outputFormat.channelCount))

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return Data()
        }

        for buffer in buffers {
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: buffer.frameLength
            ) else { continue }

            var error: NSError?
            converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard error == nil,
                  let channelData = outputBuffer.int16ChannelData else { continue }

            let frameCount = Int(outputBuffer.frameLength)
            let channelCount = Int(outputFormat.channelCount)

            for frame in 0 ..< frameCount {
                for channel in 0 ..< channelCount {
                    var sample = channelData[channel][frame]
                    pcmData.append(Data(bytes: &sample, count: 2))
                }
            }
        }

        return createWAVData(
            pcmData: pcmData,
            sampleRate: Int(outputFormat.sampleRate),
            channels: Int(outputFormat.channelCount),
            bitDepth: 16
        )
    }

    private func createWAVData(pcmData: Data, sampleRate: Int, channels: Int, bitDepth: Int) -> Data {
        var wavData = Data()

        let dataSize = UInt32(pcmData.count)
        let fileSize = dataSize + 36

        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(fileSize.littleEndian.data)
        wavData.append("WAVE".data(using: .ascii)!)

        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(UInt32(16).littleEndian.data)
        wavData.append(UInt16(1).littleEndian.data)
        wavData.append(UInt16(channels).littleEndian.data)
        wavData.append(UInt32(sampleRate).littleEndian.data)
        wavData.append(UInt32(sampleRate * channels * bitDepth / 8).littleEndian.data)
        wavData.append(UInt16(channels * bitDepth / 8).littleEndian.data)
        wavData.append(UInt16(bitDepth).littleEndian.data)

        wavData.append("data".data(using: .ascii)!)
        wavData.append(dataSize.littleEndian.data)
        wavData.append(pcmData)

        return wavData
    }
}

private extension FixedWidthInteger {
    var data: Data {
        withUnsafeBytes(of: self) { Data($0) }
    }
}
