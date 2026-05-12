package com.example.linghack2.models

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.TypeConverters
import com.example.linghack2.data.Converters
import java.util.Date
import java.util.UUID

@Entity(tableName = "word_pairs")
@TypeConverters(Converters::class)
data class WordPair(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val foreignText: String,
    val englishText: String,
    val isRemembered: Boolean = false,
    val playlistIds: List<String> = emptyList(),
    val userId: String? = null,
    val isSynced: Boolean = false,
    val timestamp: Long = System.currentTimeMillis()
)
