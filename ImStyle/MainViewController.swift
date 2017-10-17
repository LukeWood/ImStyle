// Real-time style transfer

import UIKit
import AVFoundation
import VideoToolbox

class MainViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var loadImageButton: UIButton!
    @IBOutlet weak var saveImageButton: UIButton!
    @IBOutlet weak var clearImageButton: UIButton!
    @IBOutlet weak var takePhotoButton: UIButton!
    @IBOutlet weak var styleTransferButton: UIButton!
    @IBOutlet weak var styleModelPicker: UIPickerView!
    
    let cameraSession = AVCaptureSession()
    var perform_transfer = false
    
    private var isRearCamera = true
    private var captureDevice: AVCaptureDevice?
    private var prevImage: UIImage?
    private let image_size = 720
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.styleModelPicker.delegate = modelPicker
        self.styleModelPicker.dataSource = modelPicker
        modelPicker.setMainView(mv: self)
        self.styleModelPicker.isHidden = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(MainViewController.imageTapAction))
        self.imageView.addGestureRecognizer(tap)
        self.imageView.isUserInteractionEnabled = true
        
        self.clearImageButton.isEnabled = false
        
        self.captureDevice = AVCaptureDevice.default(for: .video)!
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice!)

            cameraSession.beginConfiguration()

            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }

            let dataOutput = AVCaptureVideoDataOutput()

            dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]

            dataOutput.alwaysDiscardsLateVideoFrames = true

            if (cameraSession.canAddOutput(dataOutput) == true) {
                cameraSession.addOutput(dataOutput)
            }

            cameraSession.commitConfiguration()

            let queue = DispatchQueue(label: "com.styletransfer.video-output")
            dataOutput.setSampleBufferDelegate(self, queue: queue)

        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var frame = view.frame
        frame.size.height = frame.size.height - 35.0
        
        cameraSession.startRunning()
        
        self.updatePicker()
        
        self.styleModelPicker.isHidden = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //cameraSession.stopRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        connection.videoOrientation = .portrait
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let img = UIImage(ciImage: ciImage).resizeTo(CGSize(width: 720, height: 720))
            if let uiImage = img {
                var outImage : UIImage
                if (perform_transfer) {
                    outImage = applyStyleTransfer(uiImage: uiImage, model: model)
                } else {
                    outImage = uiImage;
                }
                DispatchQueue.main.async {
                    self.updateOutputImage(uiImage: outImage);
                }
            }
        }
    }
    
    func updateOutputImage(uiImage: UIImage) {
        if(self.takePhotoButton.isEnabled) {
            self.imageView.image = uiImage;
        }
    }
    
    private func changeCamera() {
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            
            cameraSession.stopRunning()
            cameraSession.removeInput(cameraSession.inputs[0])
            
            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }
            
            cameraSession.startRunning()
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    func updatePicker() {
        self.styleModelPicker.selectRow(modelPicker.currentStyle, inComponent: 0, animated: true)
    }
    
    @IBAction func toggle_transfer(_ sender: Any) {
        if (self.styleTransferButton.titleLabel?.text == "Undo Style") {
            self.styleTransferButton.setTitle("Style Transfer", for: [])
            self.imageView.image = self.prevImage
        } else if (!perform_transfer && self.takePhotoButton.isEnabled == false) {
            // save unstyled image
            self.prevImage = self.imageView.image!
            let image = (self.imageView.image!).scaled(to: CGSize(width: image_size, height: image_size), scalingMode: .aspectFit)
            
            let stylized_image = applyStyleTransfer(uiImage: image, model: model)
            
            // update image
            self.imageView.image = stylized_image
            
            // update SF button label
            self.styleTransferButton.setTitle("Undo Style", for: [])
        } else {
            perform_transfer = !perform_transfer
            self.saveImageButton.isEnabled = perform_transfer
        }
    }

    @IBAction func save_image(_ sender: Any) {
        self.saveToPhotoLibrary(uiImage: self.imageView.image!)
    }
    
    @IBAction func takePhotoAction(_ sender: Any) {
        cameraSession.stopRunning()
        self.takePhotoButton.isEnabled = false
        self.saveImageButton.isEnabled = true
        self.styleTransferButton.isEnabled = !perform_transfer
        self.styleModelPicker.isHidden = true
    }
    
    @IBAction func clearImageAction(_ sender: Any) {
        cameraSession.startRunning()
        self.takePhotoButton.isEnabled = true
        self.styleTransferButton.isEnabled = true
        self.clearImageButton.isEnabled = false
        
        // reset SF button label
        self.styleTransferButton.setTitle("Style Transfer", for: [])
    }
    
    @IBAction func toggleCamera(_ sender: Any) {
        if self.isRearCamera {
            self.captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front)!
            self.changeCamera()
            self.isRearCamera = false
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)!
            self.changeCamera()
            self.isRearCamera = true
        }
    }
    
    @IBAction func toggleShowStylePicker(_ sender: Any) {
        self.styleModelPicker.isHidden = !self.styleModelPicker.isHidden
    }
    
    @objc func imageTapAction() {
        if !self.styleModelPicker.isHidden {
            self.styleModelPicker.isHidden = true
        }
    }
    
    @IBAction func loadPhotoButtonPressed(_ sender: Any) {
        cameraSession.stopRunning()
        self.openPhotoLibrary()
        self.takePhotoButton.isEnabled = false
        self.saveImageButton.isEnabled = true
        self.styleTransferButton.isEnabled = true
    }
    
    func openPhotoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self as UIImagePickerControllerDelegate as? UIImagePickerControllerDelegate & UINavigationControllerDelegate
            imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            self.present(imagePicker, animated: true)
        } else {
            print("Cannot open photo library")
            return
        }
    }
    
    func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self as UIImagePickerControllerDelegate as? UIImagePickerControllerDelegate & UINavigationControllerDelegate
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera
            self.present(imagePicker, animated: true)
        } else {
            print("Cannot open camera")
            return
        }
    }
    
}

extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        defer {
            picker.dismiss(animated: true)
        }

        // get the image
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            return
        }
        
        // save to imageView
        self.imageView.image = image
        self.clearImageButton.isEnabled = true
        self.styleTransferButton.isEnabled = true
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        defer {
            picker.dismiss(animated: true)
        }
    }
}