import pytest
from routes.ocr import _legacy_values_from_dynamic, _legacy_target, _normalise_dynamic_data


@pytest.mark.parametrize("name,target", [
    ("Hemoglobin", "hemoglobin"), ("HEMOGLOBIN", "hemoglobin"), ("Hematocrit", "pcv"),
    ("Mean Corpuscular Hemoglobin", "mch"), ("Haemoglobin", "hemoglobin"), ("Hemoglobin (Hb)", "hemoglobin"), ("Hb", "hemoglobin"),
    ("Total Leucocyte Count", "wbc"), ("WBC Count", "wbc"), ("RBC Count", "rbc"),
    ("Platelet Count", "platelets"),
    ("Fasting Blood Sugar", "glucose"), ("Glucose - Fasting", "glucose"),
    ("Serum Creatinine", "creatinine"), ("SGPT (ALT)", "sgpt"), ("SGOT (AST)", "sgot"),
    ("Total Cholesterol", "cholesterol"), ("HDL Cholesterol", "hdl"), ("LDL Cholesterol", "ldl"),
    ("Triglycerides", "triglycerides"), ("HbA1c", "hba1c"), ("Vitamin B12", "vitamin_b12"),
    ("Vitamin D (25-OH)", "vitamin_d"), ("Serum Uric Acid", "uric_acid"),
    ("Bilirubin Total", "bilirubin"), ("Sodium (Na)", "sodium"), ("Potassium (K)", "potassium"),
    ("Serum Calcium", "calcium"), ("Haematocrit", "pcv"), ("PCV", "pcv"), ("TSH", "tsh"),
    ("MCV", "mcv"), ("MCH", "mch"),
])
def test_common_names_map(name, target):
    assert _legacy_target(name) == target


@pytest.mark.parametrize("name", [
    "MCHC",                                  # must NOT become hemoglobin
    "Mean Corpuscular Hemoglobin Concentration",
    "Hemoglobin A1c",                        # is hba1c, never hemoglobin
    "VLDL Cholesterol",                      # not total cholesterol, not LDL
    "Cholesterol/HDL Ratio", "LDL/HDL Ratio",
    "Urine Glucose", "Glucose Post Prandial", "Glucose Tolerance Test",
    "Direct Bilirubin", "Indirect Bilirubin",
    "Creatinine Clearance", "eGFR",
    "Platelet Distribution Width", "Mean Platelet Volume",
    "RDW", "Neutrophils %",
])
def test_lookalikes_do_not_pollute(name):
    assert _legacy_target(name) in (None, "hba1c", "mch", "ldl"), name
    # explicit stronger assertions for the dangerous ones:
    t = _legacy_target(name)
    if name == "Hemoglobin A1c": assert t == "hba1c"
    if "MCHC" in name or "Concentration" in name: assert t is None
    if name == "VLDL Cholesterol": assert t is None
    if name in ("Urine Glucose", "Glucose Post Prandial", "Glucose Tolerance Test"): assert t is None
    if name in ("Direct Bilirubin", "Indirect Bilirubin"): assert t is None


def test_full_report_populates_organ_map_columns():
    d = _normalise_dynamic_data({"tests": {
        "Haemoglobin": {"value": 13.2}, "SGPT (ALT)": {"value": 28}, "Serum Creatinine": {"value": "0.9"},
        "RBC Count": {"value": 4.6}, "Total Cholesterol": {"value": 178}, "LDL Cholesterol": {"value": 102},
        "Fasting Blood Sugar": {"value": 94}, "Sodium (Na)": {"value": 140},
    }})
    got = _legacy_values_from_dynamic(d)
    # exactly the keys organ_map_tab.dart checks: sodium, cholesterol, rbc, sgpt, glucose, creatinine
    for k in ("sodium", "cholesterol", "rbc", "sgpt", "glucose", "creatinine"):
        assert k in got, k
    assert got["creatinine"] == 0.9            # numeric string accepted
    assert got["cholesterol"] == 178.0 and got["ldl"] == 102.0   # total != LDL


def test_first_match_wins_and_qualifiers_skipped():
    d = _normalise_dynamic_data({"tests": {
        "Glucose Fasting": {"value": 90}, "Glucose Random": {"value": 140},
        "Bilirubin Total": {"value": "<0.2"},
    }})
    got = _legacy_values_from_dynamic(d)
    assert got["glucose"] == 90.0
    assert "bilirubin" not in got
