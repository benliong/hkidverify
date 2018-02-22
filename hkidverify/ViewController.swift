//
//  ViewController.swift
//  hkidverify
//
//  Created by Ben Liong on 22/2/2018.
//  Copyright © 2018 Pixelicious Software. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftyJSON

class ViewController: UIViewController {
    let session = URLSession.shared
    let captureSession = AVCaptureSession()
    var captureDevice : AVCaptureDevice?
    let stillImageOutput = AVCaptureStillImageOutput()
    @IBOutlet weak var imgOverlay: UIImageView!
    
    var googleAPIKey = "AIzaSyACBeBzbgvHouwvWzExTR1Zy84pIbAJfMc"
    var googleURL: URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        
        if let devices = AVCaptureDevice.devices() as? [AVCaptureDevice] {
            // Loop through all the capture devices on this phone
            for device in devices {
                // Make sure this particular device supports video
                if (device.hasMediaType(AVMediaType.video)) {
                    // Finally check the position and confirm we've got the back camera
                    if(device.position == AVCaptureDevice.Position.back) {
                        captureDevice = device
                        if captureDevice != nil {
                            print("Capture device found")
                            beginSession()
                        }
                    }
                }
            }
        }
    }
    
    func beginSession() {
        guard let captureDevice = captureDevice else { return }
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
            stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecType.jpeg]
            
            if captureSession.canAddOutput(stillImageOutput) {
                captureSession.addOutput(stillImageOutput)
            }
        }
        catch {
            print("error: \(error.localizedDescription)")
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.view.layer.addSublayer(previewLayer)
        previewLayer.frame = self.view.layer.frame
        captureSession.startRunning()
        self.view.addSubview(imgOverlay)
        self.delay(delay: 0.5) {
            self.saveToCamera()
        }
    }
    
    
    
    func createRequest(with imageBase64: String) {
        // Create our request URL
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        // Build our API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "TEXT_DETECTION",
                        ]
                ]
            ]
        ]
        let jsonObject = JSON(jsonRequest)
        
        // Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        
        request.httpBody = data
        
        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(request) }
    }
    
    func saveToCamera() {
        guard let videoConnection = stillImageOutput.connection(with: AVMediaType.video) else { return }
        stillImageOutput.captureStillImageAsynchronously(from: videoConnection, completionHandler: { (sampleBuffer, Error) in
            guard   let sampleBuffer = sampleBuffer,
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer),
                    let cameraImage = UIImage(data: imageData) else { return }
            let binaryImageData = self.base64EncodeImage(cameraImage)
            self.createRequest(with: binaryImageData)
        })
    }
    
    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata:Data?
        imagedata = UIImagePNGRepresentation(image)
        
//         Resize the image if it exceeds the 2MB API limit
//        if (imagedata?.count > 2097152) {
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imagedata = resizeImage(newSize, image: image)
//        }
        
        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }


    func runRequestOnBackgroundThread(_ request: URLRequest) {
        // run the request
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }
            
            self.analyzeResults(data)
        }
        
        task.resume()
    }

    func analyzeResults(_ dataToParse: Data) {
        // Update UI on the main thread
        // Use SwiftyJSON to parse results
        guard let json = try? JSON(data: dataToParse) else { return }
        let errorObj: JSON = json["error"]
        if (errorObj.dictionaryValue != [:]) {
            self.saveToCamera()
        } else {
            if let responses: JSON = json["responses"][0], let fullText = responses["fullTextAnnotation"]["text"].string {
                NSLog(fullText)
                if !fullText.contains("香港永久") {
                    self.saveToCamera()
                } else {
                    DispatchQueue.main.async(execute: {
                        
                        let alertController = UIAlertController(title: "HKID", message: fullText, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "ok", style: .default, handler: { (action) in
                            self.saveToCamera()
                        }))
                        self.present(alertController, animated: true, completion: nil)
                    })
                }
            } else {
                self.saveToCamera()
            }
        }
    }
}

