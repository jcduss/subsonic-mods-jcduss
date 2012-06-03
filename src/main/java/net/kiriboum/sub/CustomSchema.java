/*
 This file is part of Subsonic.

 Subsonic is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Subsonic is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Subsonic.  If not, see <http://www.gnu.org/licenses/>.

 Copyright 2009 (C) Sindre Mehus
 */
package net.kiriboum.sub;

import org.springframework.jdbc.core.JdbcTemplate;

import net.sourceforge.subsonic.Logger;
import net.sourceforge.subsonic.dao.schema.Schema;

/**
 * Used for creating and evolving the database schema.
 */

/*
 * jcduss : VLC remote player
 * Adds the column to store the player's URL to database model
 */
public class CustomSchema extends Schema {

	private static final Logger LOG = Logger.getLogger(CustomSchema.class);

	@Override
	public void execute(JdbcTemplate template) {

		if (!columnExists(template, "url", "player")) {
			LOG.info("Database column 'player.url' not found.  Creating it.");
			template.execute("alter table player add url varchar");
			LOG.info("Database column 'player.url' was added successfully.");
		}
	}

}