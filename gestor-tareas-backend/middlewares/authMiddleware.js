const jwt = require('jsonwebtoken');

function authMiddleware(req, res, next) {
  const authHeader = req.header('Authorization');
  console.log('Authorization Header:', authHeader);

  // Extraer el token (Formato esperado: "Bearer <token>")
  const token = authHeader?.split(' ')[1];
  console.log('Token extraído:', token);

  // Verificar existencia del token
  if (!token) {
    console.log('Token no proporcionado');
    return res.status(401).json({ msg: 'No token, acceso denegado' });
  }

  // Mostrar la clave secreta cargada
  console.log('JWT_SECRET:', process.env.JWT_SECRET);

  try {
    // Verificar token con la clave secreta
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('Token válido. Usuario decodificado:', decoded);

    // Guardar info del usuario en la request
    req.user = decoded;

    next(); // Pasar al siguiente middleware/controlador
  } catch (err) {
    console.log('Token inválido o expirado:', err.message);
    res.status(400).json({ msg: 'Token inválido' });
  }
}

module.exports = authMiddleware;
