import UIKit
import AVFoundation
import Vision

class HomeViewController: UIViewController {
        
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var cameraView: UIView!
    
    let distanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let angleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
    }

    private func setupUI() {
        cameraView = UIView()
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor, constant: 200),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        addLabels()
    }
    
    private func addLabels() {
        view.addSubview(distanceLabel)
        view.addSubview(angleLabel)
        
        NSLayoutConstraint.activate([
            distanceLabel.widthAnchor.constraint(equalToConstant: 350),
            distanceLabel.heightAnchor.constraint(equalToConstant: 50),
            distanceLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 75),
            distanceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
            
            angleLabel.widthAnchor.constraint(equalToConstant: 350),
            angleLabel.heightAnchor.constraint(equalToConstant: 50),
            angleLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 10),
            angleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25)
        ])
    }
    
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Video aygıtı bulunamadı.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            captureSession.addInput(input)
        } catch {
            print("Hata oluştu: \(error.localizedDescription)")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            print("Çıkış eklenemedi.")
            return
        }

        startCaptureSession()
        setupPreviewLayer()
    }
    
    private func startCaptureSession() {
        DispatchQueue.global().async {
            self.captureSession.startRunning()
        }
    }

    private func setupPreviewLayer() {
        DispatchQueue.main.async {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.previewLayer.videoGravity = .resizeAspectFill
            self.previewLayer.frame = self.cameraView.bounds
            self.cameraView.layer.addSublayer(self.previewLayer)
        }
    }
}

extension HomeViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        detectFace(on: pixelBuffer)
    }
    
    func detectFace(on pixelBuffer: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { request, error in
            if let error = error {
                print("Yüz tespiti sırasında hata oluştu: \(error)")
                return
            }

            guard let faceObservations = request.results as? [VNFaceObservation] else {
                print("Yüz tespiti yapılamadı veya yüz bulunamadı.")
                return
            }

            for face in faceObservations {
                let faceBoundingBox = face.boundingBox
                let faceWidth = faceBoundingBox.width
                
                let distance = self.calculateDistanceToFace(with: face)
                let angle = self.calculateAngleFromFaceObservation(faceObservation: face)
                let formattedDistance = String(format: "%.2f", distance)
                let formattedAngle = String(format: "%.2f", angle)
                
                DispatchQueue.main.async {
                    self.distanceLabel.text = "Distance to face: \(formattedDistance) cm"
                    self.angleLabel.text = "Angle to face: \(formattedAngle) degrees"
                }
            }
        }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try requestHandler.perform([faceDetectionRequest])
        } catch {
            print("Yüz tespiti isteği başarısız oldu: \(error)")
        }
    }
    
    func calculateDistanceToFace(with face: VNFaceObservation) -> CGFloat {
        let faceBoundingBox = face.boundingBox
        let faceWidth = faceBoundingBox.width

        let referenceFaceWidth: CGFloat = 10.5

        let knownDistance: CGFloat = 500.0

        let distanceInMillimeters = (referenceFaceWidth * knownDistance) / faceWidth

        let distanceInCentimeters = distanceInMillimeters / 10.0

        let faceWidthError = faceWidth - referenceFaceWidth
        let distanceError = (faceWidthError / referenceFaceWidth) * distanceInCentimeters
        
        return distanceInCentimeters / 100 - (distanceError / 100.0)
    }


    func calculateAngleFromFaceObservation(faceObservation: VNFaceObservation) -> CGFloat {
        let faceBoundingBox = faceObservation.boundingBox
        let faceCenterX = faceBoundingBox.origin.x + faceBoundingBox.size.width / 2
        let screenWidth = UIScreen.main.bounds.width

        let angleOffset = faceCenterX - screenWidth / 2
        var angle = angleOffset * (180.0 / screenWidth)

        guard let yawRollNumber = faceObservation.roll else { return angle }
        let yawRollCGFloat = CGFloat(truncating: yawRollNumber)

        if yawRollCGFloat < 0 {
            angle -= abs(yawRollCGFloat) * 90.0
        } else {
            angle += yawRollCGFloat * 90.0
        }

        return angle
    }
}
