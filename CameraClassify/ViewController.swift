//
//  ViewController.swift
//  CameraClassify
//
//  Created by 奥城健太郎 on 2019/02/05.
//  Copyright © 2019 奥城健太郎. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

//画像分類（カメラ映像）
class ViewController: UIViewController,
AVCaptureVideoDataOutputSampleBufferDelegate {
    //UI
    
    @IBOutlet weak var drawView: UIView!
    @IBOutlet weak var lblText: UILabel!
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    //モデルの生成
    var model = try! VNCoreMLModel(for: MobileNet().model)
    
    
    //====================
    //ライフサイクル
    //====================
    //ビュー表示時に呼ばれる
    override func viewDidAppear(_ animated: Bool) {
        //カメラキャプチャの開始
        startCapture()
    }
    
    
    //====================
    //アラート
    //====================
    //アラートの表示
    func showAlert(_ text: String!) {
        let alert = UIAlertController(title: text, message: nil,
                                      preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK",
                                      style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    //====================
    //カメラキャプチャ
    //====================
    //(1)カメラキャプチャの開始
    func startCapture() {
        //セッションの初期化
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        //入力の指定
        let captureDevice: AVCaptureDevice! = self.device(false)
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {return}
        guard captureSession.canAddInput(input) else {return}
        captureSession.addInput(input)
        
        //出力の指定
        let output: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
        guard captureSession.canAddOutput(output) else {return}
        captureSession.addOutput(output)
        let videoConnection = output.connection(with: AVMediaType.video)
        videoConnection!.videoOrientation = .portrait
        
        //プレビューの指定
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = self.drawView.frame
        self.view.layer.insertSublayer(previewLayer, at: 0)
        
        //カメラキャプチャの開始
        captureSession.startRunning()
    }
    
    //(2)デバイスの取得
    func device(_ frontCamera: Bool) -> AVCaptureDevice! {
        //AVCaptureDeviceのリストの取得
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
            mediaType: AVMediaType.video,
            position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices
        
        //指定したポジションを持つAVCaptureDeviceの検索
        let position: AVCaptureDevice.Position = frontCamera ? .front : .back
        for device in devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    //(3)カメラキャプチャの取得時に呼ばれる
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        //予測
        predict(sampleBuffer)
    }
    
    
    //====================
    //画像分類（カメラ映像）
    //====================
    //予測
    func predict(_  sampleBuffer: CMSampleBuffer) {
        //リクエストの生成
        let request = VNCoreMLRequest(model: self.model) {
            request, error in
            //エラー処理
            if error != nil {
                self.showAlert(error!.localizedDescription)
                return
            }
            
            //検出結果の取得
            let observations = request.results as! [VNClassificationObservation]
            var text: String = "\n"
            for i in 0..<min(3, observations.count) { //上位3件
                let probabillity = Int(observations[i].confidence*100) //信頼度
                let label = observations[i].identifier //ID
                text += "\(label) : \(probabillity)%\n"
            }
            
            //UIの更新
            DispatchQueue.main.async {
                self.lblText.text = text
            }
        }
        
        //(4)CMSampleBufferをCVPixelBufferに変換
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        //ハンドラの生成と実行
        let handler = VNImageRequestHandler(cvPixelBuffer:pixelBuffer, options:[:])
        guard (try? handler.perform([request])) != nil else {return}
    }
}

