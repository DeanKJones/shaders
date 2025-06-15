# Spectral Raytracer with Polarization Effects

This is an enhanced version of a spectral raytracer that now includes light polarization simulation and a configurable slit plane for observing polarization effects.

## Features Added

### 1. Polarization System
- **Polarization Vectors**: Each ray now carries a polarization vector perpendicular to its direction
- **Polarization Evolution**: Polarization changes correctly during reflection and refraction
- **Malus's Law**: Implemented proper polarization filtering through oriented apertures

### 2. Slit Plane Geometry
- **Configurable Slits**: Vertical or horizontal slit patterns
- **Adjustable Parameters**: Slit width and spacing can be modified
- **Interactive Controls**: Mouse-driven or automatic cycling between configurations

### 3. Enhanced Physics
- **Spectral Rendering**: Maintains original 350-950nm wavelength range simulation
- **Polarization-Dependent Transmission**: Light intensity varies based on polarization alignment with slits
- **Fresnel Equations**: Enhanced with polarization considerations
- **Realistic Material Interactions**: Polarization effects on different material types

## File Structure

- `buffer-a.wgsl` - Main raytracing shader with polarization implementation
- `common.wgsl` - Shared definitions, structures, and scene description
- `image.wgsl` - Final image processing and tone mapping
- `test.html` - Testing interface with interactive controls

## Interactive Controls

- **Mouse X Position**: Toggle between vertical (left) and horizontal (right) slits
- **Mouse Y Position**: Control slit width and spacing
- **Auto Mode**: Automatically cycles through configurations if no mouse input

## Physics Demonstrated

1. **Polarization Filtering**: Observe how light intensity changes when polarization alignment varies with slit orientation
2. **Spectral Effects**: See how different wavelengths interact with polarized apertures
3. **Material Interactions**: Watch polarization changes during reflection/refraction events
4. **Interference Patterns**: Enhanced visual effects from polarization-dependent transmission

## Usage

Load the shaders in a WebGL/WebGPU environment that supports WGSL (such as Shadertoy or a custom WebGPU application). The system will:

1. Initialize random polarization for primary rays
2. Trace rays through the scene with polarization evolution
3. Apply polarization filtering at the slit plane
4. Combine spectral and polarization effects for final rendering

## Expected Visual Effects

- **Intensity Variations**: Different brightness levels based on slit orientation
- **Spectral Shifts**: Color changes due to wavelength-dependent polarization effects
- **Dynamic Patterns**: Evolving visual patterns as slit parameters change
- **Realistic Optics**: Physically accurate representation of polarized light behavior

## Technical Details

The implementation uses:
- Polarization vectors stored as vec3 perpendicular to ray direction
- Malus's law for transmission calculations (I = I₀ cos²θ)
- Proper vector mathematics for polarization evolution
- Enhanced material interaction functions
- Interactive parameter control system

This enhanced raytracer provides an educational and visually compelling demonstration of polarization optics combined with spectral rendering.
