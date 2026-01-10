#!/bin/bash

# ==========================================
#  Group Generator
# ==========================================
fancy_output() {
    local frames=("|" "/" "-" "\\")
    local i=0
    local duration=20
    local count=0

    printf "\r                                                        \r"
    while (( count < duration )); do
        printf "\rMenampilkan hasil kelompok... ${frames[i]} \033[K"
        i=$(( (i + 1) % 4 ))
        ((count++))
        sleep 0.05
    done
    printf "\r                                                        \r"
}

# ==========================================
#  SLOW OUTPUT (SKIPPABLE)
# ==========================================
SKIP=0
slow_echo() {
    local text="$1"
    local delay=0.01

    # Cek apakah ada input masuk untuk skip
    if read -t 0.001 -n 10000; then
        SKIP=1
    fi

    if (( SKIP == 1 )); then
        echo "$text"
        return
    fi

    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:i:1}"

        # Sambil ngetik, cek lagi apakah user tekan tombol
        if read -t 0.001 -n 10000; then
            SKIP=1
            printf "%s" "${text:i+1}" # Tampilkan sisa teks langsung
            echo ""
            return
        fi
        sleep "$delay"
    done
    echo ""
}

while true; do
    read -p "Masukkan jumlah maksimal anggota per kelompok: " MAX_PER_GROUP
    read -p "Minimal laki-laki per kelompok: " MIN_L
    read -p "Minimal perempuan per kelompok: " MIN_P

    stty -echo
    L_NAMES=()
    P_NAMES=()

    if [[ ! -f file.txt ]]; then
        echo "Error: file.txt tidak ditemukan."
        exit 1
    fi

    # Membaca file dengan benar (Menjaga Nama Lengkap)
    while IFS=',' read -r name gender; do
        [[ -z "$name" ]] && continue
        name=$(echo "$name" | xargs)
        gender=$(echo "$gender" | xargs)

        if [[ "$gender" == "L" ]]; then
            L_NAMES+=("$name")
        else
            P_NAMES+=("$name")
        fi
    done < file.txt

    TOTAL=$(( ${#L_NAMES[@]} + ${#P_NAMES[@]} ))
    (( TOTAL == 0 )) && echo "File kosong!" && exit 1

    # Validasi Kecukupan Anggota
    GROUP_COUNT=$(( (TOTAL + MAX_PER_GROUP - 1) / MAX_PER_GROUP ))
    REQ_L=$(( GROUP_COUNT * MIN_L ))
    REQ_P=$(( GROUP_COUNT * MIN_P ))

    impossible=0
    (( ${#L_NAMES[@]} < REQ_L || ${#P_NAMES[@]} < REQ_P )) && impossible=1

    # ==========================================
    #  PENGACAKAN DATA (FIXED: Menjaga Spasi Nama)
    # ==========================================
    # mapfile digunakan agar nama seperti "Alex The Great" tidak pecah
    if (( ${#L_NAMES[@]} > 0 )); then
        mapfile -t L_NAMES < <(printf "%s\n" "${L_NAMES[@]}" | shuf)
    fi
    if (( ${#P_NAMES[@]} > 0 )); then
        mapfile -t P_NAMES < <(printf "%s\n" "${P_NAMES[@]}" | shuf)
    fi

    fancy_output

    echo ""
    if (( impossible == 0 )); then
        echo "Valid Group telah ditemukan"
    else
        echo "WARNING: Syarat minimal tidak bisa dipenuhi sepenuhnya. Menggunakan sisa yang ada."
    fi
    echo ""

    # ==========================================
    #  PROSES PEMBAGIAN (LOGIKA MERATA)
    # ==========================================

    # Hitung jumlah kelompok yang optimal agar tidak ada sisa 1
    # Jika total 25 dan max 6, maka group_count = 5. (25/5 = 5 orang per group)
    GROUP_COUNT=$(( (TOTAL + MAX_PER_GROUP - 1) / MAX_PER_GROUP ))

    # Inisialisasi array kelompok sebagai array dua dimensi (simulasi)
    for ((g=1; g<=GROUP_COUNT; g++)); do
        eval "GROUP_$g=()"
    done

    # 1. Bagikan syarat minimal Laki-laki ke tiap kelompok
    for ((g=1; g<=GROUP_COUNT; g++)); do
        for ((i=0; i<MIN_L && ${#L_NAMES[@]} > 0; i++)); do
            eval "GROUP_$g+=('\"${L_NAMES[0]} (L)\"')"
            L_NAMES=("${L_NAMES[@]:1}")
        done
    done

    # 2. Bagikan syarat minimal Perempuan ke tiap kelompok
    for ((g=1; g<=GROUP_COUNT; g++)); do
        for ((i=0; i<MIN_P && ${#P_NAMES[@]} > 0; i++)); do
            eval "GROUP_$g+=('\"${P_NAMES[0]} (P)\"')"
            P_NAMES=("${P_NAMES[@]:1}")
        done
    done

    # 3. Bagikan sisa anggota secara bergilir (Round Robin) agar rata
    current_g=1
    COMBINED_REMAINING=("${L_NAMES[@]/%/ (L)}" "${P_NAMES[@]/%/ (P)}")
    # Acak sisa gabungan agar gender tetap variatif
    [[ ${#COMBINED_REMAINING[@]} -gt 0 ]] && mapfile -t COMBINED_REMAINING < <(printf "%s\n" "${COMBINED_REMAINING[@]}" | shuf)

    for member in "${COMBINED_REMAINING[@]}"; do
        eval "GROUP_$current_g+=('\"$member\"')"
        current_g=$(( (current_g % GROUP_COUNT) + 1 ))
    done

    # 4. Tampilkan Hasil
    for ((g=1; g<=GROUP_COUNT; g++)); do
        slow_echo "=== Kelompok $g ==="
        eval "temp_members=(\"\${GROUP_$g[@]}\")"
        for member in "${temp_members[@]}"; do
            # Menghapus tanda kutip extra dari eval
            clean_member=$(echo "$member" | sed 's/^"//;s/"$//')
            slow_echo "   - $clean_member"
        done
        echo ""
    done
    stty echo
    read -p "Ingin generate ulang? (Y/N): " ulang
    [[ ! "$ulang" =~ ^[Yy]$ ]] && break
done

echo "Selesai!"
