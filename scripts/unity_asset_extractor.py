#!/usr/bin/env python3
"""Extract and convert Unity/Synty assets for Dreamcast"""

import unitypack
from PIL import Image
import subprocess
import os
import json
import sys
import argparse
import struct
import wave
import numpy as np
from pathlib import Path
import logging
from tqdm import tqdm

class UnityToDreamcastConverter:
    def __init__(self, config_path="/etc/dreamcast/asset_pipeline.json"):
        # Set up logging
        logging.basicConfig(level=logging.INFO, 
                          format='%(asctime)s - %(levelname)s - %(message)s')
        self.logger = logging.getLogger(__name__)
        
        # Load config if exists, otherwise use defaults
        self.config = self.load_config(config_path)
        
    def load_config(self, config_path):
        """Load configuration or use defaults"""
        default_config = {
            "texture": {
                "max_size": 512,
                "formats": ["pvr", "vq"],
                "compression_quality": "high"
            },
            "audio": {
                "format": "adpcm",
                "sample_rate": 22050,
                "channels": 1
            },
            "model": {
                "vertex_format": "float",
                "index_format": "uint16",
                "max_vertices": 65536
            }
        }
        
        if os.path.exists(config_path):
            try:
                with open(config_path) as f:
                    loaded_config = json.load(f)
                    # Merge with defaults
                    default_config.update(loaded_config)
            except Exception as e:
                self.logger.warning(f"Failed to load config: {e}, using defaults")
        
        return default_config
    
    def extract_assets(self, unity_file, output_dir):
        """Main extraction function"""
        os.makedirs(output_dir, exist_ok=True)
        
        self.logger.info(f"Opening Unity asset bundle: {unity_file}")
        
        try:
            with open(unity_file, "rb") as f:
                bundle = unitypack.load(f)
                
                # Count total assets for progress
                total_objects = sum(len(asset.objects) for asset in bundle.assets)
                
                with tqdm(total=total_objects, desc="Extracting assets") as pbar:
                    for asset in bundle.assets:
                        for obj_id, obj in asset.objects.items():
                            pbar.update(1)
                            
                            if obj.type == "Texture2D":
                                self.extract_texture(obj, output_dir)
                            elif obj.type == "AudioClip":
                                self.extract_audio(obj, output_dir)
                            elif obj.type == "Mesh":
                                self.extract_mesh(obj, output_dir)
                            elif obj.type == "Material":
                                self.extract_material(obj, output_dir)
                                
        except Exception as e:
            self.logger.error(f"Failed to process Unity file: {e}")
            raise
    
    def extract_texture(self, obj, output_dir):
        """Extract and convert textures to Dreamcast format"""
        try:
            data = obj.read()
            if not hasattr(data, 'image') or data.image is None:
                self.logger.warning(f"Skipping texture {data.name}: No image data")
                return
                
            texture = data.image
            name = self.sanitize_filename(data.name)
            
            # Create textures subdirectory
            tex_dir = os.path.join(output_dir, "textures")
            os.makedirs(tex_dir, exist_ok=True)
            
            # Save as PNG first
            png_path = os.path.join(tex_dir, f"{name}.png")
            texture.save(png_path)
            self.logger.info(f"Extracted texture: {name}")
            
            # Convert to Dreamcast formats
            self.convert_to_pvr(png_path, tex_dir)
            self.convert_to_vq(png_path, tex_dir)
            
        except Exception as e:
            self.logger.error(f"Failed to extract texture: {e}")
    
    def extract_audio(self, obj, output_dir):
        """Extract and convert audio to Dreamcast ADPCM format"""
        try:
            data = obj.read()
            name = self.sanitize_filename(data.name)
            
            # Create audio subdirectory
            audio_dir = os.path.join(output_dir, "audio")
            os.makedirs(audio_dir, exist_ok=True)
            
            # Save raw audio data
            raw_path = os.path.join(audio_dir, f"{name}.raw")
            with open(raw_path, "wb") as f:
                f.write(data.samples)
            
            # Convert to WAV then ADPCM
            wav_path = os.path.join(audio_dir, f"{name}.wav")
            self.raw_to_wav(raw_path, wav_path, data.frequency, data.channels)
            
            # Convert WAV to ADPCM for Dreamcast
            adpcm_path = os.path.join(audio_dir, f"{name}.adx")
            self.convert_to_adpcm(wav_path, adpcm_path)
            
            # Clean up intermediate files
            os.remove(raw_path)
            if os.path.exists(adpcm_path):
                os.remove(wav_path)
                
            self.logger.info(f"Extracted audio: {name}")
            
        except Exception as e:
            self.logger.error(f"Failed to extract audio: {e}")
    
    def extract_mesh(self, obj, output_dir):
        """Extract mesh data for Dreamcast"""
        try:
            data = obj.read()
            name = self.sanitize_filename(data.name)
            
            # Create models subdirectory
            model_dir = os.path.join(output_dir, "models")
            os.makedirs(model_dir, exist_ok=True)
            
            # Export as custom Dreamcast format
            dc_path = os.path.join(model_dir, f"{name}.dcm")
            self.export_dreamcast_mesh(data, dc_path)
            
            # Also export as OBJ for reference
            obj_path = os.path.join(model_dir, f"{name}.obj")
            self.export_obj(data, obj_path)
            
            self.logger.info(f"Extracted mesh: {name}")
            
        except Exception as e:
            self.logger.error(f"Failed to extract mesh: {e}")
    
    def extract_material(self, obj, output_dir):
        """Extract material properties"""
        try:
            data = obj.read()
            name = self.sanitize_filename(data.name)
            
            # Create materials subdirectory
            mat_dir = os.path.join(output_dir, "materials")
            os.makedirs(mat_dir, exist_ok=True)
            
            # Save material properties as JSON
            mat_data = {
                "name": name,
                "shader": getattr(data, "shader", "unknown"),
                "properties": {}
            }
            
            # Extract material properties
            if hasattr(data, "properties"):
                for prop_name, prop_value in data.properties.items():
                    if isinstance(prop_value, (int, float, str, bool)):
                        mat_data["properties"][prop_name] = prop_value
                    elif hasattr(prop_value, "__dict__"):
                        mat_data["properties"][prop_name] = str(prop_value)
            
            mat_path = os.path.join(mat_dir, f"{name}.json")
            with open(mat_path, "w") as f:
                json.dump(mat_data, f, indent=2)
                
            self.logger.info(f"Extracted material: {name}")
            
        except Exception as e:
            self.logger.error(f"Failed to extract material: {e}")
    
    def convert_to_pvr(self, input_path, output_dir):
        """Convert image to Dreamcast PVR format"""
        # First, ensure power-of-2 dimensions
        img = Image.open(input_path)
        width, height = self.nearest_power_of_2(img.size)
        
        if (width, height) != img.size:
            img = img.resize((width, height), Image.Resampling.LANCZOS)
            temp_path = input_path.replace('.png', '_resized.png')
            img.save(temp_path)
            input_path = temp_path
        
        output_path = os.path.join(output_dir, 
                                  os.path.basename(input_path).replace('.png', '.pvr'))
        
        # Use custom pvr_converter if available
        if self.command_exists('pvr_converter'):
            # First convert PNG to raw RGB565
            raw_path = input_path.replace('.png', '.raw')
            self.png_to_raw_rgb565(input_path, raw_path)
            
            cmd = ['pvr_converter', raw_path, output_path]
            subprocess.run(cmd, check=True)
            os.remove(raw_path)
        else:
            # Fallback: create a simple PVR file
            self.create_simple_pvr(input_path, output_path)
        
        # Clean up temp file if created
        if 'resized' in input_path:
            os.remove(input_path)
    
    def convert_to_vq(self, input_path, output_dir):
        """Convert image to VQ compressed format for Dreamcast"""
        output_path = os.path.join(output_dir,
                                  os.path.basename(input_path).replace('.png', '.vq'))
        
        # VQ compression is complex, so we'll create a placeholder
        # In production, you'd use a proper VQ compressor
        self.logger.info(f"VQ compression placeholder for: {input_path}")
        
        # For now, just copy as a marker
        with open(output_path + '.info', 'w') as f:
            f.write(f"VQ compressed version of {os.path.basename(input_path)}\n")
    
    def convert_to_adpcm(self, wav_path, output_path):
        """Convert WAV to ADPCM format for Dreamcast"""
        if self.command_exists('adxtool'):
            cmd = ['adxtool', '-e', wav_path, output_path]
            subprocess.run(cmd, check=True)
        else:
            # Fallback: use sox if available
            if self.command_exists('sox'):
                cmd = ['sox', wav_path, '-t', 'ima', output_path]
                subprocess.run(cmd, check=True)
            else:
                self.logger.warning("No ADPCM converter available, keeping WAV format")
    
    def raw_to_wav(self, raw_path, wav_path, sample_rate, channels):
        """Convert raw audio data to WAV format"""
        with open(raw_path, 'rb') as f:
            raw_data = f.read()
        
        # Assume 16-bit samples
        with wave.open(wav_path, 'w') as wav:
            wav.setnchannels(channels)
            wav.setsampwidth(2)  # 16-bit
            wav.setframerate(sample_rate)
            wav.writeframes(raw_data)
    
    def export_dreamcast_mesh(self, mesh_data, output_path):
        """Export mesh in custom Dreamcast-optimized format"""
        with open(output_path, 'wb') as f:
            # Write header
            f.write(b'DCM\x01')  # Magic + version
            
            # Write vertex count
            vertex_count = len(mesh_data.vertices) // 3
            f.write(struct.pack('<I', vertex_count))
            
            # Write vertices
            for i in range(0, len(mesh_data.vertices), 3):
                x, y, z = mesh_data.vertices[i:i+3]
                f.write(struct.pack('<fff', x, y, z))
            
            # Write face count
            face_count = len(mesh_data.indices) // 3
            f.write(struct.pack('<I', face_count))
            
            # Write indices
            for i in range(0, len(mesh_data.indices), 3):
                a, b, c = mesh_data.indices[i:i+3]
                f.write(struct.pack('<HHH', a, b, c))
            
            # Write UV count if available
            if hasattr(mesh_data, 'uv') and mesh_data.uv:
                uv_count = len(mesh_data.uv) // 2
                f.write(struct.pack('<I', uv_count))
                for i in range(0, len(mesh_data.uv), 2):
                    u, v = mesh_data.uv[i:i+2]
                    f.write(struct.pack('<ff', u, v))
            else:
                f.write(struct.pack('<I', 0))
    
    def export_obj(self, mesh_data, output_path):
        """Export mesh as OBJ for reference"""
        with open(output_path, 'w') as f:
            f.write(f"# Exported from Unity asset\n")
            f.write(f"# Vertices: {len(mesh_data.vertices)//3}\n")
            
            # Write vertices
            for i in range(0, len(mesh_data.vertices), 3):
                x, y, z = mesh_data.vertices[i:i+3]
                f.write(f"v {x} {y} {z}\n")
            
            # Write UVs if available
            if hasattr(mesh_data, 'uv') and mesh_data.uv:
                for i in range(0, len(mesh_data.uv), 2):
                    u, v = mesh_data.uv[i:i+2]
                    f.write(f"vt {u} {v}\n")
            
            # Write faces
            for i in range(0, len(mesh_data.indices), 3):
                a, b, c = mesh_data.indices[i:i+3]
                # OBJ indices are 1-based
                f.write(f"f {a+1} {b+1} {c+1}\n")
    
    def png_to_raw_rgb565(self, png_path, raw_path):
        """Convert PNG to raw RGB565 format"""
        img = Image.open(png_path).convert('RGB')
        width, height = img.size
        
        with open(raw_path, 'wb') as f:
            for y in range(height):
                for x in range(width):
                    r, g, b = img.getpixel((x, y))
                    # Convert to RGB565
                    rgb565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
                    f.write(struct.pack('<H', rgb565))
    
    def create_simple_pvr(self, png_path, pvr_path):
        """Create a simple PVR file as fallback"""
        img = Image.open(png_path).convert('RGB')
        width, height = img.size
        
        with open(pvr_path, 'wb') as f:
            # PVR header
            f.write(b'PVRV')  # Magic
            f.write(struct.pack('<I', 8))  # Header size
            f.write(struct.pack('<H', width))
            f.write(struct.pack('<H', height))
            f.write(struct.pack('<B', 0x01))  # RGB565 format
            f.write(struct.pack('<B', 0x01))  # Data type
            f.write(b'\x00\x00')  # Padding
            
            # Write pixel data
            for y in range(height):
                for x in range(width):
                    r, g, b = img.getpixel((x, y))
                    rgb565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
                    f.write(struct.pack('<H', rgb565))
    
    def nearest_power_of_2(self, size):
        """Find nearest power of 2 dimensions"""
        import math
        max_size = self.config["texture"]["max_size"]
        w = min(2 ** math.ceil(math.log2(size[0])), max_size)
        h = min(2 ** math.ceil(math.log2(size[1])), max_size)
        return w, h
    
    def sanitize_filename(self, name):
        """Sanitize filename for filesystem"""
        # Remove or replace invalid characters
        invalid_chars = '<>:"/\\|?*'
        for char in invalid_chars:
            name = name.replace(char, '_')
        return name.strip()
    
    def command_exists(self, cmd):
        """Check if a command exists"""
        return subprocess.run(['which', cmd], 
                            capture_output=True, 
                            text=True).returncode == 0

def main():
    parser = argparse.ArgumentParser(
        description="Extract and convert Unity/Synty assets for Dreamcast"
    )
    parser.add_argument('input', help='Unity asset bundle file')
    parser.add_argument('output', help='Output directory')
    parser.add_argument('--config', default='/etc/dreamcast/asset_pipeline.json',
                       help='Configuration file path')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    converter = UnityToDreamcastConverter(args.config)
    
    try:
        converter.extract_assets(args.input, args.output)
        print(f"\n✅ Successfully extracted assets to: {args.output}")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
