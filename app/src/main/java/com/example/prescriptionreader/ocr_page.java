package com.example.prescriptionreader;

import android.content.pm.PackageManager;
import android.Manifest;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ScrollView;
import android.widget.LinearLayout;
import android.graphics.Color;
import android.view.View;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;
import androidx.appcompat.app.AlertDialog;
import com.google.common.util.concurrent.ListenableFuture;
import java.util.concurrent.ExecutionException;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.ImageCaptureException;
import androidx.core.app.ActivityCompat;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.Text;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.Query;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.StorageReference;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.Date;

public class ocr_page extends AppCompatActivity {

    private PreviewView viewFinder;
    private TextView scanResultsText;
    private Button captureButton;
    private Button flashButton;
    private Button historyButton;
    private Camera camera;
    private ProcessCameraProvider cameraProvider;
    private ImageCapture imageCapture;
    private TextRecognizer textRecognizer;
    private boolean isFlashOn = false;
    private FirebaseFirestore db;
    private FirebaseStorage storage;

    private static final int PERMISSION_REQUEST_CODE = 100;
    private static final String[] REQUIRED_PERMISSIONS = new String[]{
            Manifest.permission.CAMERA
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_ocr_page);

        // Initialize Firebase
        db = FirebaseFirestore.getInstance();
        storage = FirebaseStorage.getInstance();

        initializeViews();
        setupTextRecognizer();

        if (allPermissionsGranted()) {
            startCamera();
        } else {
            requestPermissions();
        }
    }

    private void initializeViews() {
        viewFinder = findViewById(R.id.viewFinder);
        scanResultsText = findViewById(R.id.scanResultsText);
        captureButton = findViewById(R.id.captureButton);
        flashButton = findViewById(R.id.flashButton);
        historyButton = findViewById(R.id.historyButton);

        captureButton.setOnClickListener(v -> captureImage());
        flashButton.setOnClickListener(v -> toggleFlash());
        historyButton.setOnClickListener(v -> showHistory());
    }

    private void setupTextRecognizer() {
        textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS);
    }

    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture =
                ProcessCameraProvider.getInstance(this);

        cameraProviderFuture.addListener(() -> {
            try {
                cameraProvider = cameraProviderFuture.get();
                bindCameraUseCases();
            } catch (ExecutionException | InterruptedException e) {
                Toast.makeText(this, "Error starting camera: " + e.getMessage(),
                        Toast.LENGTH_SHORT).show();
            }
        }, ContextCompat.getMainExecutor(this));
    }

    private void bindCameraUseCases() {
        if (cameraProvider == null) {
            return;
        }

        // Camera selector
        CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                .build();

        // Preview use case
        Preview preview = new Preview.Builder().build();
        preview.setSurfaceProvider(viewFinder.getSurfaceProvider());

        // Image capture use case
        imageCapture = new ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build();

        try {
            cameraProvider.unbindAll();
            camera = cameraProvider.bindToLifecycle(this, cameraSelector,
                    preview, imageCapture);
        } catch (Exception e) {
            Toast.makeText(this, "Error binding camera: " + e.getMessage(),
                    Toast.LENGTH_SHORT).show();
        }
    }

    private void captureImage() {
        if (imageCapture == null) return;

        // Create temporary file
        File photoFile = new File(getExternalCacheDir(),
                "Prescription_" + System.currentTimeMillis() + ".jpg");

        ImageCapture.OutputFileOptions outputOptions =
                new ImageCapture.OutputFileOptions.Builder(photoFile).build();

        imageCapture.takePicture(outputOptions, ContextCompat.getMainExecutor(this),
                new ImageCapture.OnImageSavedCallback() {
                    @Override
                    public void onImageSaved(@NonNull ImageCapture.OutputFileResults output) {
                        processImage(photoFile);
                    }

                    @Override
                    public void onError(@NonNull ImageCaptureException exception) {
                        Toast.makeText(ocr_page.this,
                                "Error capturing image: " + exception.getMessage(),
                                Toast.LENGTH_SHORT).show();
                    }
                });
    }

    private void processImage(File imageFile) {
        try {
            InputImage image = InputImage.fromFilePath(this, Uri.fromFile(imageFile));

            textRecognizer.process(image)
                    .addOnSuccessListener(text -> {
                        String recognizedText = processRecognizedText(text);
                        runOnUiThread(() -> {
                            scanResultsText.setText(recognizedText);
                            // Save to Firebase after successful recognition
                            saveToFirebase(recognizedText, imageFile);
                        });
                    })
                    .addOnFailureListener(e -> {
                        Toast.makeText(this, "Text recognition failed: " + e.getMessage(),
                                Toast.LENGTH_SHORT).show();
                    });
        } catch (IOException e) {
            Toast.makeText(this, "Error processing image: " + e.getMessage(),
                    Toast.LENGTH_SHORT).show();
        }
    }

    private String processRecognizedText(Text text) {
        StringBuilder result = new StringBuilder();
        for (Text.TextBlock block : text.getTextBlocks()) {
            result.append(block.getText()).append("\n");
        }
        return result.toString();
    }

    private void saveToFirebase(String recognizedText, File imageFile) {
        // Upload image to Firebase Storage
        StorageReference storageRef = storage.getReference()
                .child("prescriptions/" + imageFile.getName());

        storageRef.putFile(Uri.fromFile(imageFile))
                .addOnSuccessListener(taskSnapshot -> {
                    // Get download URL and save to Firestore
                    storageRef.getDownloadUrl().addOnSuccessListener(uri -> {
                        Map<String, Object> scan = new HashMap<>();
                        scan.put("text", recognizedText);
                        scan.put("imageUrl", uri.toString());
                        scan.put("timestamp", new Date());

                        db.collection("prescriptions")
                                .add(scan)
                                .addOnSuccessListener(documentReference ->
                                        Toast.makeText(this, "Saved to history",
                                                Toast.LENGTH_SHORT).show())
                                .addOnFailureListener(e ->
                                        Toast.makeText(this, "Error saving to history",
                                                Toast.LENGTH_SHORT).show());
                    });
                })
                .addOnFailureListener(e ->
                        Toast.makeText(this, "Error uploading image",
                                Toast.LENGTH_SHORT).show());
    }

    private void showHistory() {
        // Create a dialog to show history
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Scan History");

        // Create a ScrollView to hold the history
        ScrollView scrollView = new ScrollView(this);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(16, 16, 16, 16);

        db.collection("prescriptions")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .get()
                .addOnSuccessListener(queryDocumentSnapshots -> {
                    for (DocumentSnapshot document : queryDocumentSnapshots) {
                        String text = document.getString("text");
                        TextView textView = new TextView(this);
                        textView.setText(text);
                        textView.setPadding(0, 8, 0, 8);
                        layout.addView(textView);

                        View divider = new View(this);
                        divider.setBackgroundColor(Color.GRAY);
                        divider.setLayoutParams(new LinearLayout.LayoutParams(
                                LinearLayout.LayoutParams.MATCH_PARENT, 1));
                        layout.addView(divider);
                    }
                    scrollView.addView(layout);
                    builder.setView(scrollView);
                    builder.setPositiveButton("Close", null);
                    builder.show();
                })
                .addOnFailureListener(e ->
                        Toast.makeText(this, "Error loading history",
                                Toast.LENGTH_SHORT).show());
    }

    private void toggleFlash() {
        if (camera != null && camera.getCameraInfo().hasFlashUnit()) {
            isFlashOn = !isFlashOn;
            camera.getCameraControl().enableTorch(isFlashOn);
            flashButton.setText(isFlashOn ? "Flash Off" : "Flash On");
        }
    }

    private boolean allPermissionsGranted() {
        for (String permission : REQUIRED_PERMISSIONS) {
            if (ContextCompat.checkSelfPermission(this, permission)
                    != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }

    private void requestPermissions() {
        ActivityCompat.requestPermissions(this, REQUIRED_PERMISSIONS,
                PERMISSION_REQUEST_CODE);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (allPermissionsGranted()) {
                startCamera();
            } else {
                Toast.makeText(this, "Permissions not granted by the user.",
                        Toast.LENGTH_SHORT).show();
                finish();
            }
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (cameraProvider != null) {
            cameraProvider.unbindAll();
        }
    }
}