# CleanCore — Selected References

This is a curated bibliography of works that informed the technical design of CleanCore, organized by topical area. The full reference list of the FYP report is in `Docs/Report Clean Core.pdf`; this document is a one-page summary for quick reference during evaluation.

---

## 1. Smart Waste Management and IoT Sensing

- Zanella, A., Bui, N., Castellani, A., Vangelista, L., & Zorzi, M. (2014). *Internet of Things for Smart Cities*. **IEEE Internet of Things Journal**, 1(1), 22–32. — Foundational IoT-for-cities survey; framing reference for smart-city sensor architectures.

- Anagnostopoulos, T., Zaslavsky, A., Kolomvatsos, K., Medvedev, A., Amirian, P., Morley, J., & Hadjieftymiades, S. (2017). *Challenges and Opportunities of Waste Management in IoT-Enabled Smart Cities: A Survey*. **IEEE Transactions on Sustainable Computing**, 2(3), 275–289. — Domain framing for IoT-enabled municipal waste collection.

- Idwan, S., Mahmood, I., Zubairi, J. A., & Matar, I. (2020). *Optimal Management of Solid Waste in Smart Cities Using Internet of Things*. **Wireless Personal Communications**, 110(1), 485–501. — Representative IoT-bin sensor system.

## 2. Waste Classification with Deep Learning

- Yang, M., & Thung, G. (2016). *Classification of Trash for Recyclability Status*. **Stanford CS229 Project Report**. — TrashNet dataset and CNN baseline; the most cited public dataset for waste classification.

- Bircanoğlu, C., Atay, M., Beşer, F., Genç, Ö., & Kızrak, M. A. (2018). *RecycleNet: Intelligent Waste Sorting Using Deep Neural Networks*. **2018 Innovations in Intelligent Systems and Applications (INISTA)**, 1–7. — MobileNet fine-tuning on TrashNet variants.

- Adedeji, O., & Wang, Z. (2019). *Intelligent Waste Classification System Using Deep Learning Convolutional Neural Network*. **Procedia Manufacturing**, 35, 607–612. — ResNet50 transfer-learning approach to waste categorization.

## 3. Object Detection Architecture (YOLO family)

- Redmon, J., Divvala, S., Girshick, R., & Farhadi, A. (2016). *You Only Look Once: Unified, Real-Time Object Detection*. **Proc. IEEE CVPR**, 779–788. — The original single-shot detection paradigm.

- Bochkovskiy, A., Wang, C.-Y., & Liao, H.-Y. M. (2020). *YOLOv4: Optimal Speed and Accuracy of Object Detection*. **arXiv:2004.10934**. — Architectural ancestor of YOLOv8; introduces CSPDarknet and the mosaic augmentation we use.

- Jocher, G., Chaurasia, A., & Qiu, J. (2023). *Ultralytics YOLOv8*. **GitHub**: https://github.com/ultralytics/ultralytics. — The implementation we built on. Anchor-free detection head, decoupled classification/regression branches, Distribution Focal Loss.

## 4. Route Optimization and TSP Heuristics

- Croes, G. A. (1958). *A Method for Solving Traveling-Salesman Problems*. **Operations Research**, 6(6), 791–812. — Original 2-opt heuristic; the edge-swap technique CleanCore implements at `Backend/main.py` lines 427–442.

- Lin, S., & Kernighan, B. W. (1973). *An Effective Heuristic Algorithm for the Traveling-Salesman Problem*. **Operations Research**, 21(2), 498–516. — Lin–Kernighan k-opt; the state-of-the-art comparator we explicitly chose not to implement at FYP scope.

- Christofides, N. (1976). *Worst-Case Analysis of a New Heuristic for the Travelling Salesman Problem*. **Carnegie Mellon University Technical Report**. — Provides the 1.5-approximation guarantee for metric TSP; context for our greedy + 2-opt approximation quality.

## 5. Sensor-Driven Fault and Anomaly Detection (Building / IoT systems)

- Schein, J., & Bushby, S. T. (2006). *A Hierarchical Rule-Based Fault Detection and Diagnostic Method for HVAC Systems*. **HVAC&R Research**, 12(1), 111–125. — Classical building fault-detection-and-diagnosis (FDD); the same problem class as fill-level inference from low-frequency IoT snapshots.

- Yu, Z., Haghighat, F., & Fung, B. C. M. (2016). *Advances and Challenges in Building Engineering and Data Mining Applications for Energy-Efficient Communities*. **Sustainable Cities and Society**, 25, 33–38. — Representative of the building-sensor-data ML literature.

- Habib, U., Zucker, G., et al. (multiple). *Automated Fault Detection and Diagnosis Methods for Building Data*. — Dr. Habib's TU Wien PhD work on ML-driven FDD from building sensor streams; structurally the same problem class as CleanCore's fill-level inference from IoT snapshots. Full citation: see https://scholar.google.com.pk/citations?user=HN8JX8IAAAAJ

---

## Note on dataset provenance

The training data referenced in this work is proprietary and was provided under a legally binding agreement with three European waste-management operators. It is not derivable from any of the publicly cited references above. See `Docs/Clean_Core_Final_Addendum.pdf` Section 3 for the full provenance statement.
