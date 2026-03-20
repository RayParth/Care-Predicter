from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
from routes_auth import router as auth_router
from routes_vitals import router as vitals_router
from routes_ocr import router as ocr_router
from routes_consult import router as consult_router

# Create all database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Care Predicter API",
    description="AI-Driven Health Monitoring Backend",
    version="1.0.0"
)

# Allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include all routes
app.include_router(auth_router)
app.include_router(vitals_router)
app.include_router(ocr_router)
app.include_router(consult_router)

@app.get("/")
def root():
    return {
        "status": "Care Predicter API running",
        "version": "1.0.0",
        "endpoints": ["/auth", "/vitals", "/ocr", "/consult"]
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}