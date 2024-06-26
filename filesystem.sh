#!/bin/bash

# Validación 0: Verificar si el script se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse como root."
    exit 1
fi

# Mostrar nombres de discos disponibles
echo "Los siguientes nombres de discos son los que puede particionar:"
lsblk -d -o NAME

# Solicitar al usuario el disco a particionar
read -p "Ingrese el disco a particionar (por ejemplo, sda, sdb, etc.): " disk

# Validar si el disco existe
if ! ls "/dev/$disk" >/dev/null 2>&1; then
    echo "Error: El dispositivo de bloque $disk no existe."
    exit 1
fi

# Construir el nombre completo del dispositivo
device="/dev/$disk"

# Desmontar el disco si está montado
if mount | grep "$device" >/dev/null; then
    umount "$device"
    echo "El disco $device estaba montado y se ha desmontado correctamente."
fi

# Eliminar cualquier firma de filesystem existente en el disco
wipefs -a "$device"
echo "Se ha eliminado la firma de filesystem existente en $device."

# Solicitar nombre del VG
read -p "Ingrese el nombre del Grupo de Volúmenes (VG): " vg_name

# Validar nombre del VG
if [[ -z "$vg_name" ]]; then
    echo "Error: El nombre del Grupo de Volúmenes (VG) no puede estar vacío."
    exit 1
fi

# Solicitar tamaño del VG
read -p "Ingrese el tamaño del Grupo de Volúmenes (e.g., 20G): " vg_size

if [[ ! "$vg_size" =~ ^[0-9]+[GM]$ ]]; then
    echo "Error: El tamaño del Grupo de Volúmenes '$vg_size' no es válido. Debe ser un número seguido de 'G' (gigabytes) o 'M' (megabytes)."
    exit 1
fi

# Crear el Grupo de Volúmenes (VG)
echo "Creando Grupo de Volúmenes $vg_name en $device..."
vgcreate "$vg_name" "$device"

# Solicitar nombre del LV
read -p "Ingrese el nombre del Volumen Lógico (LV): " lv_name

# Validar nombre del LV
if [[ -z "$lv_name" ]]; then
    echo "Error: El nombre del Volumen Lógico (LV) no puede estar vacío."
    exit 1
fi

# Solicitar tamaño del LV
read -p "Ingrese el tamaño del Volumen Lógico (e.g., 10G): " lv_size

if [[ ! "$lv_size" =~ ^[0-9]+[GM]$ ]]; then
    echo "Error: El tamaño del Volumen Lógico '$lv_size' no es válido. Debe ser un número seguido de 'G' (gigabytes) o 'M' (megabytes)."
    exit 1
fi

# Crear el Volumen Lógico (LV) con el tamaño y nombre especificados
echo "Creando Volumen Lógico $lv_name en $vg_name con tamaño $lv_size..."
lvcreate -L "$lv_size" -n "$lv_name" "$vg_name"

# Obtener el nombre completo del Volumen Lógico
lv_path="/dev/$vg_name/$lv_name"

# Solicitar tipo de filesystem
list_of_fs=("ext4" "vfat" "xfs")
echo "Tipos de filesystems válidos: ${list_of_fs[@]}"
read -p "Ingrese el tipo de filesystem (e.g., ext4, vfat, xfs): " fs_type

# Validar tipo de filesystem ingresado
if ! echo "${list_of_fs[@]}" | grep -qw "$fs_type"; then
    echo "Error: El tipo de filesystem '$fs_type' no es válido."
    exit 1
fi

# Crear el filesystem en el Volumen Lógico
echo "Creando el filesystem $fs_type en $lv_path..."
mkfs -t "$fs_type" "$lv_path"

# Solicitar punto de montaje
read -p "Ingrese el punto de montaje (e.g., /mnt/myfs): " mount_point

# Validación 3: Verificar si el punto de montaje no está en uso
if [ -d "$mount_point" ]; then
    echo "Error: El punto de montaje $mount_point ya está en uso."
    exit 1
else
    mkdir -p "$mount_point"
    echo "El punto de montaje $mount_point se creó correctamente."
fi

# Montar el filesystem
echo "Montando el dispositivo $lv_path en $mount_point..."
mount "$lv_path" "$mount_point"

# Agregar entrada a /etc/fstab
lv_uuid=$(blkid -s UUID -o value "$lv_path")
echo "Agregando entrada a /etc/fstab..."
echo "UUID=$lv_uuid $mount_point $fs_type defaults 0 2" >> /etc/fstab

echo "Proceso completado. Filesystem creado y montado en $mount_point."
